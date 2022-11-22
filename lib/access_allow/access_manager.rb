# frozen_string_literal: true

module AccessAllow
  class AccessManager
    VIOLATION_TYPES = %i[severe hidden redirect not_permitted].freeze

    def initialize
      @required_rules = []
      @action_rules = []
      @named_rules_map = {}
      @all_actions_rules = []
      @no_match_rule = { violation: :severe }
    end

    # When initialising an access manager for a controller make sure to clone the current parent controllers rules
    def initialize_clone(parent_manager)
      @required_rules = parent_manager.required_rules.deep_dup
      @action_rules = parent_manager.action_rules.deep_dup
      @named_rules_map = parent_manager.named_rules_map.deep_dup
      @all_actions_rules = parent_manager.all_actions_rules.deep_dup
      @no_match_rule = parent_manager.no_match_rule.deep_dup
    end

    def add_allow_rule(rule, to, with = nil, as = nil)
      insert_access_rule(parse_rule(rule, to: to, with: with, as: as))
    end

    def add_required_rule(rule, violation, with = nil, handler = nil)
      unless VIOLATION_TYPES.include?(violation)
        raise StandardError, "You must provide a valid violation type"
      end
      insert_required_rule(rule, with, violation, handler)
    end

    def configure_no_match(violation_type, &block)
      rule = { violation: violation_type }
      rule[:handler] = block if block_given?
      @no_match_rule = rule
    end

    # Rule is applied like this:
    #
    # First apply any required rules, ie all must pass to allow user to progress
    #
    # Then apply allow rules, where any pass will allow user to progress:
    # * if there is a constraint on an action name, check that
    # * if it has user type requirement, then apply that next
    # * if it has a perms requirement, apply that after
    # * if it has custom rules, apply those

    # Compare against all configured rules which have actions
    def allow_action?(user, controller, current_action)
      # Required checks must all pass
      required_rules.each do |config|
        permitted_or_violation = execute_required_rule(config, user, controller, current_action)
        return permitted_or_violation unless permitted_or_violation == true
      end

      # Check action rules
      allowed =
        action_rules.any? { |config| execute_rule(config, user, controller, current_action) }
      return true if allowed

      # return no-match
      no_match_rule
    end

    # Evaluate specific rules. Ie we dont check action match, we just find if there are any checks that pass
    # for the current context. Used in view helper. The rules are defined with access_allow and a name or alias.
    def allow?(rules, user, current_controller)
      Array
        .wrap(rules)
        .any? do |rule|
          rule_configs = named_rules_map[rule]
          rule_configs&.any? { |config| execute_rule(config, user, current_controller) }
        end
    end

    # Introspection methods

    def no_match_violation
      no_match_rule[:violation]
    end

    def named_rule_exists?(name)
      !named_rules_map[name].nil?
    end

    def required_check_exists?(name)
      required_rules.any? do |r|
        r[:rules_set][:all]&.include?(name) || r[:rules_set][:any]&.include?(name)
      end
    end

    protected

    attr_reader :required_rules, :action_rules, :named_rules_map, :all_actions_rules, :no_match_rule

    private

    def parse_rule(rule, with: nil, as: nil, to: nil)
      # If rule is a hash then its rules + perms - one key is single rule, multiple considered AND
      # If an array then AND condition on the rules
      actions = Array.wrap(to)
      given_names = Array.wrap(as)
      if actions.empty? && given_names.empty?
        raise StandardError,
              "You must specify the actions which the rule applies to or if a check must have a name"
      end
      {
        aliases: given_names.presence || actions,
        rules_set: prepare_rule_set(rule),
        perms: parse_permissions(with),
        actions: actions
      }
    end

    # Parse the (optional) permissions configuration for the rule, defined with the `with:` option
    def parse_permissions(perm_config)
      return if perm_config.blank?

      # A permission comprises of a namespace key, and with a single or array of permission names.
      # If multiple are specified they all must apply
      perm_config.to_a.flat_map do |c|
        namespace, perm_name = c
        if perm_name.is_a?(Array)
          perm_name.map { |n| { namespace => n } }
        else
          { namespace => perm_name }
        end
      end
    end

    def insert_required_rule(rule, with, violation, handler)
      config = {
        rules_set: prepare_rule_set(rule),
        perms: parse_permissions(with),
        violation: violation
      }
      config[:handler] = handler if handler
      required_rules << config
    end

    def prepare_rule_set(rules)
      return rules if rules.is_a?(Hash) && (rules[:any] || rules[:all])
      { all: Array.wrap(rules) }
    end

    def insert_access_rule(parsed_rule)
      # Or add alias and/or action rule
      aliased_as = parsed_rule[:aliases]
      aliased_as&.each do |alias_name|
        named_rules_map[alias_name] = [] if named_rules_map[alias_name].nil?
        named_rules_map[alias_name] << parsed_rule
      end
      return if parsed_rule[:actions].blank?
      all_actions_rules << parsed_rule if parsed_rule[:actions].include?(:all)
      action_rules << parsed_rule
    end

    # To execute a rule:
    # - check that the action is valid if specified
    # - check that the user has required abilities if specified
    # - apply the rules (all rules for the given allow config) to check if it passes for the current context
    def execute_rule(config, user, controller, action_name = nil)
      return if action_name && !allowed_action?(config[:actions], action_name)
      execute_rules_set(config[:rules_set], config[:perms], user, controller, action_name)
    end

    # Required rules either pass or return their configured violation state
    def execute_required_rule(config, user, controller, action_name)
      if execute_rules_set(config[:rules_set], config[:perms], user, controller, action_name)
        return true
      end
      config.slice(:violation, :handler)
    end

    def execute_rules_set(rules_set, perms, user, controller, action_name)
      return unless user_has_perms?(user, perms)
      if rules_set[:all]
        rules_set[:all].all? do |rule|
          Array.wrap(rule).all? { |r| apply_rule(r, user, controller, action_name) }
        end
      elsif rules_set[:any]
        rules_set[:any].any? do |rule|
          Array.wrap(rule).all? { |r| apply_rule(r, user, controller, action_name) }
        end
      else
        raise NotImplementedError, "Unknown rule set"
      end
    end

    # Check specified action is even got a rule to apply to it
    def allowed_action?(actions, action_name)
      actions.include?(:all) || actions.include?(action_name)
    end

    # Check if the user has permissions defined in the rule
    def user_has_perms?(user, perms)
      return true if perms.blank?
      perms.all? { |perm| AccessAllow::Check.call(user, perm) }
    end

    # Some rules are predefined, otherwise apply the rule by calling the methods on the controller
    # which the rule defines, which are named after the rule with a `allow_` prefix
    def apply_rule(rule, user, controller, action_name)
      case rule
      when :public
        true
      when :authenticated_user
        user.present?
      else
        apply_custom_rule(rule, user, controller, action_name)
      end
    end

    # Apply the rule by calling the appropriate `allow_#{name}` instance method on the controller
    # The method can be optionally called with the current user being tested against the rule, and optionally
    # the rule configuration itself.
    def apply_custom_rule(rule, user, controller, action_name)
      controller.instance_exec(user, rule: rule, action_name: action_name) do |uut, rule_info|
        check_name = "allow_#{rule}?".to_sym
        unless respond_to?(check_name)
          raise NotImplementedError, "Check #{check_name} not implemented!"
        end
        case method(check_name).arity
        when 1
          send(check_name, uut)
        when 2
          send(check_name, uut, rule_info)
        else
          send(check_name)
        end
      end
    end
  end
end
