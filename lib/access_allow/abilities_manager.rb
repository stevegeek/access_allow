# frozen_string_literal: true

module AccessAllow
  class AbilitiesManager
    def initialize(user)
      @user = user
    end

    def has?(ability_namespace, ability_name)
      namespace = namespaced_context(ability_namespace)
      namespace[ability_name]
    end

    def to_a
      @to_a ||=
        combined_role_and_user_assigned.flat_map do |namespace, abilities|
          abilities
            .to_a
            .each_with_object([]) do |config, arr|
              ability, permitted = config
              arr << [namespace, ability.to_sym] if permitted
            end
        end
    end

    private

    attr_reader :user

    def namespaced_context(ability_namespace)
      context = combined_role_and_user_assigned[ability_namespace]
      raise StandardError, "Permission namespace unknown: #{ability_namespace}" unless context
      context
    end

    def combined_role_and_user_assigned
      @combined_role_and_user_assigned ||=
        begin
          base_perms = role_assigned.deep_dup
          user.send(AccessAllow.configuration.permissions_association_name).each do |perm|
            namespace, name = AccessAllow::Abilities.parse_qualified_name(perm.ability_name)

            # We only assign if the permission already exists in the base role based configs
            next if base_perms.dig(namespace, name).nil?
            base_perms[namespace][name] = true
          end
          base_perms
        end
    end

    def role_assigned
      unless role_based_abilities[user_type_key]
        raise(StandardError, "User type (#{user_type_key}) has no permissions defined")
      end
      unless role_based_abilities[user_type_key][user_role_key]
        raise(
          StandardError,
          "Role (#{user_role_key}) for user type (#{user_type_key}) has no permissions defined"
        )
      end
      role_based_abilities[user_type_key][user_role_key]
    end

    def role_based_abilities
      AccessAllow.configuration.roles_and_permissions
    end

    def user_type_key
      user.class.name.underscore.to_sym
    end

    def user_role_key
      role = user.send(AccessAllow.configuration.role_method_name)
      (role.presence || "primary").to_sym
    end

    def about_user
      "#{user.class} with ID #{user.id}"
    end
  end
end
