require "test_helper"

class AccessAllowTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert AccessAllow::VERSION
  end

  test "it can be configured with a block" do
    original_config = AccessAllow.configuration.roles_and_permissions.dup
    begin
      test_config = {user: {admin: {namespace: {ability: true}}}}
      AccessAllow.configure do |config|
        config.roles_and_permissions = test_config
      end
      assert_equal test_config, AccessAllow.configuration.roles_and_permissions
    ensure
      # Restore the original configuration
      AccessAllow.configure do |config|
        config.roles_and_permissions = original_config
      end
    end
  end

  test "configuration has default values" do
    config = AccessAllow::Configuration.new
    assert_equal({}, config.roles_and_permissions)
    assert_equal :current_user, config.current_user_method
    assert_equal :permissions, config.permissions_association_name
    assert_equal :role, config.role_method_name
  end

  test "has expected error classes" do
    assert defined?(AccessAllow::ViolationError)
    assert defined?(AccessAllow::ResponseForbiddenError)
  end
end
