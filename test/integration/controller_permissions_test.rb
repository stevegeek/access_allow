require "test_helper"

# This test demonstrates how to test permission rules in a Rails controller context
class ControllerPermissionsTest < ActionDispatch::IntegrationTest
  setup do
    # Configure roles and permissions for our test
    AccessAllow.configure do |config|
      config.roles_and_permissions = {
        user: {
          owner: {
            test: {
              ability1: true,
              ability2: true
            }
          },
          primary: {
            test: {
              ability1: false,
              ability2: false
            }
          }
        }
      }
    end

    # Set up test data
    @admin_user = User.create!(role: "owner")
    @regular_user = User.create!(role: "primary")

    # Add abilities to the regular user through permissions
    @permission = Permission.create!(user: @regular_user, ability_name: "test/ability1")
  end

  teardown do
    # Restore the original configuration
    AccessAllow.configure do |config|
      config.roles_and_permissions = {
        user: {
          owner: {
            test: { ability1: true }
          }
        }
      }
    end
  end

  # Create a test controller that includes the DSL and defines the necessary rules
  class TestController < ActionController::Base
    include AccessAllow::ControllerAccessDsl

    # Allow public access to index
    access_allow :public, to: :index

    # Require authentication for show
    access_allow :authenticated_user, to: :show

    # Allow only users with the specified ability to access edit
    access_allow :authenticated_user, with: {test: :ability1}, to: :edit, as: :can_edit

    # Allow only admin users to access admin actions
    access_allow :admin, to: :admin

    # Allow owner to view private content
    access_allow :owner, to: :private

    # Special action with custom redirect handler
    access_allow :admin, to: :redirect_action

    # Allow only users with multiple abilities
    access_allow :authenticated_user, with: {test: [:ability1, :ability2]}, to: :multi_ability, as: :can_multi

    # Action with rule aliased to multiple names
    access_allow :owner, to: :aliased_action, as: [:owner_alias1, :owner_alias2]

    # Required rule for all actions
    access_require :basic_security, violation: :not_permitted

    # Another required rule with custom handler - we'll only use this in specific tests

    # Configure no match behavior for actions not explicitly allowed
    access_no_match :hidden do
      "/not_found_path"
    end

    # Define check implementations
    def allow_owner?(user)
      user&.role == "owner"
    end

    def allow_admin?(user)
      allow_owner?(user)
    end

    def allow_basic_security?(user)
      true # Always pass in our tests
    end
    
    def allow_custom_required?(user)
      user && user.role == "custom" # This will always fail for our test users
    end

    # Implement actions
    def index
      render plain: "Public content"
    end

    def show
      render plain: "Authenticated content"
    end

    def edit
      render plain: "Editable content"
    end

    def admin
      render plain: "Admin content"
    end

    def private
      render plain: "Private content"
    end

    def redirect_action
      render plain: "Redirect action content"
    end

    def multi_ability
      render plain: "Multiple abilities content"
    end

    def aliased_action
      render plain: "Aliased action content"
    end

    def not_allowed_action
      render plain: "This should never be accessible"
    end

    # Override current_user to use our passed user
    attr_accessor :test_current_user
    def current_user
      @test_current_user
    end

    # Provide a simple root path for redirect tests
    def root_path
      "/root"
    end
  end

  test "public action is accessible without a user" do
    controller = TestController.new
    controller.test_current_user = nil

    # Check rule directly
    result = TestController.access_manager.allow_action?(nil, controller, :index)
    assert_equal true, result

    # Check named rule using access_allowed?
    controller.test_current_user = nil
    assert controller.access_allowed?(:index)
  end

  test "authenticated action requires a user" do
    controller = TestController.new

    # Without a user
    controller.test_current_user = nil
    result = TestController.access_manager.allow_action?(nil, controller, :show)
    assert_equal :hidden, result[:violation]

    # With a user
    controller.test_current_user = @regular_user
    result = TestController.access_manager.allow_action?(@regular_user, controller, :show)
    assert_equal true, result
  end

  test "ability-restricted action checks user abilities" do
    controller = TestController.new

    # Regular user with the required ability
    controller.test_current_user = @regular_user

    # First verify they can access with the permission
    assert controller.access_allowed?(:can_edit)

    # Remove the ability by removing the permission
    @permission.destroy

    # Clear any cached abilities
    @regular_user.reload

    # User no longer has the ability, should not be allowed
    refute controller.access_allowed?(:can_edit)
  end

  test "admin action requires admin role" do
    controller = TestController.new

    # Regular user cannot access admin action
    controller.test_current_user = @regular_user
    result = TestController.access_manager.allow_action?(@regular_user, controller, :admin)
    assert_equal :hidden, result[:violation]

    # Admin user can access admin action
    controller.test_current_user = @admin_user
    result = TestController.access_manager.allow_action?(@admin_user, controller, :admin)
    assert_equal true, result
  end

  test "owner action requires owner role" do
    controller = TestController.new

    # Regular user cannot access private action
    controller.test_current_user = @regular_user
    result = TestController.access_manager.allow_action?(@regular_user, controller, :private)
    assert_equal :hidden, result[:violation]

    # Owner user can access private action
    controller.test_current_user = @admin_user
    result = TestController.access_manager.allow_action?(@admin_user, controller, :private)
    assert_equal true, result
  end

  test "access_allowed? works with named rules" do
    controller = TestController.new

    # Regular user with the required ability
    controller.test_current_user = @regular_user
    assert controller.access_allowed?(:can_edit)

    # Regular user without admin privileges
    refute controller.access_allowed?(:admin)

    # Admin user with admin privileges
    controller.test_current_user = @admin_user
    assert controller.access_allowed?(:admin)
  end

  test "access_allowed? works with multiple rule names" do
    controller = TestController.new
    controller.test_current_user = @regular_user

    # Regular user has :can_edit but not :admin
    assert controller.access_allowed?(:can_edit)
    refute controller.access_allowed?(:admin)

    # Check if user has ANY of the specified permissions
    assert controller.access_allowed?(:can_edit, :admin)

    # Admin user has both
    controller.test_current_user = @admin_user
    assert controller.access_allowed?(:can_edit, :admin)
  end

  test "no_match configuration affects non-explicitly allowed actions" do
    controller = TestController.new
    controller.test_current_user = @admin_user

    # Action that has no explicit rule
    result = TestController.access_manager.allow_action?(@admin_user, controller, :not_allowed_action)
    assert_equal :hidden, result[:violation]
  end

  test "required rules are applied to all actions" do
    controller = TestController.new
    
    # Temporarily override basic_security to fail
    def controller.allow_basic_security?(user)
      false
    end

    # Even for otherwise allowed actions like index
    result = TestController.access_manager.allow_action?(@admin_user, controller, :index)
    assert_equal({violation: :not_permitted}, result)
  end

  test "access_log_user_info formats user info correctly" do
    controller = TestController.new
    
    # With a user
    controller.test_current_user = @admin_user
    assert_match(/User \d+/, controller.send(:access_log_user_info))
    
    # Without a user
    controller.test_current_user = nil
    assert_equal "An unauthenticated user", controller.send(:access_log_user_info)
  end

  test "rule with multiple ability requirements" do
    controller = TestController.new
    controller.test_current_user = @regular_user
    
    # User only has ability1, but needs both ability1 and ability2
    # First, confirm user has ability1
    assert_equal true, AccessAllow::Check.call(@regular_user, test: :ability1)
    # But doesn't have ability2
    assert_equal false, AccessAllow::Check.call(@regular_user, test: :ability2)
    
    # So multi_ability should fail
    result = TestController.access_manager.allow_action?(@regular_user, controller, :multi_ability)
    assert_equal :hidden, result[:violation]
    
    # Add the second permission
    @permission2 = Permission.create!(user: @regular_user, ability_name: "test/ability2")
    @regular_user.reload
    
    # Now the user should have both abilities
    assert_equal true, AccessAllow::Check.call(@regular_user, test: :ability1)
    assert_equal true, AccessAllow::Check.call(@regular_user, test: :ability2)
    
    # And should be able to access the multi_ability action
    result = TestController.access_manager.allow_action?(@regular_user, controller, :multi_ability)
    assert_equal true, result
    
    # Clean up
    @permission2.destroy
  end
  
  test "rule with multiple aliases" do
    controller = TestController.new
    controller.test_current_user = @admin_user
    
    # Owner can access the action via any of its aliases
    assert controller.access_allowed?(:owner_alias1)
    assert controller.access_allowed?(:owner_alias2)
    
    # Regular user cannot access via any alias
    controller.test_current_user = @regular_user
    refute controller.access_allowed?(:owner_alias1)
    refute controller.access_allowed?(:owner_alias2)
  end

  test "configure_no_match with custom handler" do
    # Test the API directly instead
    temp_manager = AccessAllow::AccessManager.new
    
    custom_handler = proc { "/custom_path" }
    temp_manager.configure_no_match(:redirect, &custom_handler)
    
    # Verify the configuration was applied
    rule = temp_manager.instance_variable_get(:@no_match_rule)
    assert_equal :redirect, rule[:violation]
    assert_equal custom_handler, rule[:handler]
  end

  test "no_match with custom handler" do
    controller = TestController.new
    controller.test_current_user = @admin_user
    
    # Set up a temporary access manager without any rules for a specific action
    temp_manager = AccessAllow::AccessManager.new
    temp_manager.configure_no_match(:hidden) { "/not_found_path" }
    
    # Execute allow_action with an action that has no rules
    result = temp_manager.allow_action?(@admin_user, controller, :no_rule_action)
    assert_equal :hidden, result[:violation]
    assert result[:handler].is_a?(Proc)
    
    # Execute the handler
    handler = result[:handler]
    path = controller.instance_exec(&handler)
    assert_equal "/not_found_path", path
  end

  test "custom violation type and inherited access rules" do
    # Create a subclass of our test controller
    subclass = Class.new(TestController) do
      # Add a new rule specifically for this subclass
      access_allow :owner, to: :subclass_action
      
      def subclass_action
        render plain: "Subclass action"
      end
    end
    
    # The subclass should inherit all parent rules
    controller = subclass.new
    controller.test_current_user = @admin_user
    
    # Check a rule from the parent
    result = subclass.access_manager.allow_action?(@admin_user, controller, :admin)
    assert_equal true, result
    
    # Check the rule specific to the subclass
    result = subclass.access_manager.allow_action?(@admin_user, controller, :subclass_action)
    assert_equal true, result
    
    # Regular user doesn't have access to the subclass action
    controller.test_current_user = @regular_user
    result = subclass.access_manager.allow_action?(@regular_user, controller, :subclass_action)
    assert_equal :hidden, result[:violation]
  end
end
