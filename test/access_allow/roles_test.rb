require "test_helper"

class AccessAllow::RolesTest < ActiveSupport::TestCase
  setup do
    # Store original config
    @original_config = AccessAllow.configuration.roles_and_permissions.dup
    
    # Set up test config
    test_config = {
      user: {
        admin: { test: { ability1: true } },
        staff: { test: { ability2: true } }
      },
      customer: {
        primary: { test: { ability3: true } }
      }
    }
    
    AccessAllow.configure do |config|
      config.roles_and_permissions = test_config
    end
  end

  teardown do
    # Restore original config
    AccessAllow.configure do |config|
      config.roles_and_permissions = @original_config
    end
  end

  test "humanized_name formats role name for i18n" do
    I18n.expects(:t).with("abilities.user.roles.admin").returns("Administrator")
    result = AccessAllow::Roles.humanized_name(:user, :admin)
    assert_equal "Administrator", result
  end

  test "for? verifies if role exists for a user type" do
    assert AccessAllow::Roles.for?(:user, :admin)
    assert AccessAllow::Roles.for?(:user, :staff)
    assert AccessAllow::Roles.for?(:customer, :primary)
    refute AccessAllow::Roles.for?(:user, :missing)
    refute AccessAllow::Roles.for?(:missing, :admin)
  end

  test "roles_for returns all roles for a user type" do
    user_roles = AccessAllow::Roles.roles_for(:user)
    assert_equal 2, user_roles.size
    assert_includes user_roles, :admin
    assert_includes user_roles, :staff
    
    customer_roles = AccessAllow::Roles.roles_for(:customer)
    assert_equal 1, customer_roles.size
    assert_includes customer_roles, :primary
    
    # Non-existent type
    missing_roles = AccessAllow::Roles.roles_for(:missing)
    assert_empty missing_roles
  end
end