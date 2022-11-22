# frozen_string_literal: true

module AccessAllow
  class Roles
    class << self
      # Get a human readable version of the role key
      def humanized_name(type, role)
        I18n.t("abilities.#{type}.roles.#{role}")
      end

      # Check roles are valid for specific user types

      def for?(type, role)
        roles_for(type).include?(role.to_sym)
      end

      def roles_for(type)
        configuration[type.to_sym]&.keys || []
      end

      private

      def configuration
        AccessAllow.configuration.roles_and_permissions
      end
    end
  end
end
