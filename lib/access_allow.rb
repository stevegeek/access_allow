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
    attr_accessor :roles_and_permissions, :current_user_method, :permissions_association_name, :role_method_name

    def initialize
      @roles_and_permissions = {}
      @current_user_method = :current_user
      @permissions_association_name = :permissions
      @role_method_name = :role
    end
  end
end
