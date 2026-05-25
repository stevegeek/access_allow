require "access_allow/version"
require "access_allow/railtie"
require "access_allow/abilities"
require "access_allow/abilities_manager"
require "access_allow/access_manager"
require "access_allow/check"
require "access_allow/controller_access_dsl"
require "access_allow/roles"

module AccessAllow
  class ViolationError < StandardError; end

  class ResponseForbiddenError < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end
  end

  class Configuration
    attr_writer :logger
    attr_accessor :roles_and_permissions, :current_user_method, :permissions_association_name,
      :role_method_name, :permission_check_log_level

    def initialize
      @roles_and_permissions = {}
      @current_user_method = :current_user
      @permissions_association_name = :permissions
      @role_method_name = :role
      @logger = nil
      # Level used for the per-check "user cannot do X" lines. These fire on
      # every failed ability check and are normal control flow (menu
      # visibility, scoping), not violations — so they default to :debug.
      # Set to nil to silence them entirely. Actual access violations are
      # logged separately by ControllerAccessDsl at :info/:error.
      @permission_check_log_level = :debug
    end

    # Falls back to Rails.logger at call time (not memoised) so a logger
    # swapped in tests or after boot is always respected.
    def logger
      @logger || (defined?(Rails) ? Rails.logger : nil)
    end
  end
end
