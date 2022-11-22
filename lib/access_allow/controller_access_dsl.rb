# frozen_string_literal: true

module AccessAllow
  # Setup rules and configuration to specify access for a controller. Either specific actions or all actions.
  module ControllerAccessDsl
    extend ActiveSupport::Concern

    included do
      helper_method :access_allowed?

      # Add a before action to check `allow` permissions rules. Note this is a 'prepend' as we
      # want to try to ensure this happens before anything else.
      prepend_before_action do |controller|
        ensure_authenticated_before_perms_check if respond_to?(:ensure_authenticated_before_perms_check)
        access_result = self.class.access_manager.allow_action?(
          send(AccessAllow.configuration.current_user_method),
          controller,
          controller.action_name.to_sym
        )
        next true if access_result == true
        Rails.logger.info("Blocked access for #{access_log_user_info} to access '#{access_log_action_tried}'")
        handle_access_violation(access_result)
      end
    end

    # The DSL of the access rule configuration is defined below
    class_methods do
      # The access controls are inherited to controller subclasses
      def inherited(subclass)
        subclass.instance_variable_set(:@access_manager, @access_manager.clone)
        super
      end

      # Configure what should happen when no access rule matches the action being executed
      def access_no_match(violation, &block)
        access_manager.configure_no_match(violation, &block)
      end

      # TODO: consider a `if:` conditional allowed on rules
      # Specify an access requirement, that must pass for any other action access checks to pass
      # The default violation level is :severe
      def access_require(check, with: nil, violation: :severe, &block)
        access_manager.add_required_rule(check, violation, with, block)
      end

      # Specify an access rule requirement for a specific action or set of actions. You can optionally
      # also specify what abilities are required to match the rule. Using `as:` and no `to:` actions you can also
      # specify an access rule which is not used when actions are executed but instead can be checked by the given name,
      # thus allowing one to define a check that is used inside the processing of an action rather than before it.
      # You can also specify an action rule with `to:` and then alias it to a named check with `as:`
      def access_allow(check, with: nil, to: nil, as: nil)
        access_manager.add_allow_rule(check, to, with, as)
      end

      # Create a new manager instance for this particular controller
      def access_manager
        @access_manager ||= AccessAllow::AccessManager.new
      end
    end

    # `access_allowed?` is exposed as a view helper to execute checks or allow rules and return if they
    # passed or not. Useful for doing conditional work in the view or a controller action
    def access_allowed?(*check_rules)
      self.class.access_manager.allow?(
        check_rules,
        send(AccessAllow.configuration.current_user_method),
        self
      )
    end

    protected

    # When required access rules are violated, or when no match on an action occurs, the result from the access
    # manager is processed here.
    def handle_access_violation(access_result)
      case access_result[:violation]
      when :redirect
        redirect_destination = access_result[:handler] ? instance_exec(&access_result[:handler]) : root_path
        raise ::AccessAllow::ResponseForbiddenError, "Not permitted" unless redirect_destination
        Rails.logger.info("#{access_log_user_info} tried to access a page that they can't access and they were " \
          "redirected to '#{redirect_destination}'. (#{access_log_action_tried})")
        redirect_to redirect_destination
      when :not_permitted
        Rails.logger.info("#{access_log_user_info} tried to access a page that they can't access and they were " \
          "told about it. (#{access_log_action_tried})")
        raise ::AccessAllow::ResponseForbiddenError, "Not permitted"
      when :hidden
        Rails.logger.info("#{access_log_user_info} tried to access a page that they can't access and they won't " \
          "know exists (#{access_log_action_tried})")
        raise ActionController::RoutingError, "Not Found"
      else
        log_severe_access_violation_and_not_found
      end
    end

    def log_severe_access_violation_and_not_found
      Rails.logger.error(
        "#{access_log_user_info} tried to access a page that they can't access and" \
          " it is considered suspicious they should attempt to see it. The action was: #{access_log_action_tried}"
      )
      raise ActionController::RoutingError, "Not Found"
    end

    def access_log_user_info
      user = send(AccessAllow.configuration.current_user_method)
      user ? "User #{user.id}" : "An unauthenticated user"
    end

    def access_log_action_tried
      "#{controller_name}##{action_name}"
    end
  end
end
