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
        log_failed_check
        return false
      end
      ability_manager.has?(ability_namespace, ability_name).tap { |can| log_failed_check unless can }
    end

    def possible!
      possible? || raise(AccessAllow::ViolationError, error_message)
    end

    private

    attr_reader :user, :ability_namespace, :ability_name, :ability_manager

    # A failed check is normal control flow, not a violation, so it logs at
    # the configured level (default :debug; nil silences it). Actual access
    # violations are logged by ControllerAccessDsl at :info/:error.
    def log_failed_check
      level = AccessAllow.configuration.permission_check_log_level
      return unless level
      AccessAllow.configuration.logger&.public_send(level) { error_message }
    end

    def about_user
      user ? "#{user.class} with ID #{user.id}" : "Unauthenticated user"
    end

    def error_message
      "#{about_user} cannot do '#{ability_name}'"
    end
  end
end
