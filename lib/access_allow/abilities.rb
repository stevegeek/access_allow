# frozen_string_literal: true

module AccessAllow
  class Abilities
    class << self
      def qualified_name(ability_namespace, ability_name)
        raise StandardError, "You can't have blank ability names" if ability_namespace.blank? || ability_name.blank?
        "#{ability_namespace}/#{ability_name}"
      end

      def parse_qualified_name(name)
        parts = name.split("/").map do |part|
          raise StandardError "Ability namespaces or names cannot be blank" if part.blank?
          part.to_sym
        end
        return parts if parts.size == 2
        raise StandardError "Ability name must have a namespace and name (was #{name})"
      end

      def humanized_name(type, ability_namespace, ability_name)
        I18n.t("abilities.#{type}.abilities.#{ability_namespace}.#{ability_name}")
      end
    end
  end
end
