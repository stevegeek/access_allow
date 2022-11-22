# frozen_string_literal: true

module AccessAllow
  class Check
    class << self
      def call(user, config)
        build_perms_checker(user, config).possible?
      end

      def call!(user, config)
        build_perms_checker(user, config).possible!
      end

      private

      def build_perms_checker(user, config)
        perm_namespace, perm_name = config.to_a.first
        new(user, perm_namespace, perm_name)
      end
    end

    def initialize(user, ability_namespace, ability_name)
      @user = user
      @ability_manager = user ? AccessAllow::AbilitiesManager.new(user) : nil
      @ability_namespace = ability_namespace.to_sym
      @ability_name = ability_name.to_sym
    end

    def possible?
      unless user
        Rails.logger.info error_message(false)
        return false
      end
      ability_manager.has?(ability_namespace, ability_name).tap { |can| Rails.logger.info error_message(can) }
    end

    def possible!
      possible? || raise(AccessAllow::ViolationError, error_message(false))
    end

    private

    attr_reader :user, :ability_namespace, :ability_name, :ability_manager

    # Error messages

    def about_user
      user ? "#{user.class} with ID #{user.id}" : "Unauthenticated user"
    end

    def error_message(can)
      "#{about_user} #{can ? "can" : "cannot"} do '#{ability_name}'"
    end
  end
end
