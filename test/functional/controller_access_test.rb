require "test_helper"

# This test demonstrates testing access control via direct interaction with
# AccessManager through a controller that includes the ControllerAccessDsl
class ControllerAccessTest < ActiveSupport::TestCase
  setup do
    # Configure access control for testing
    @original_config = AccessAllow.configuration.roles_and_permissions.dup
    
    AccessAllow.configure do |config|
      config.roles_and_permissions = {
        user: {
          admin: {
            test: { ability1: true, ability2: true }
          },
          regular: {
            test: { ability1: false, ability2: false }
          }
        }
      }
    end
    
    # Create a test controller class
    @controller_class = Class.new(ActionController::Base) do
      include AccessAllow::ControllerAccessDsl
      
      # Allow public access to :index
      access_allow :public, to: :index
      
      # Require authentication for :show
      access_allow :authenticated_user, to: :show
      
      # Require admin for :admin
      access_allow :admin, to: :admin
      
      # Require specific permission for :special
      access_allow :authenticated_user, with: {test: :ability1}, to: :special
      
      # Define a named rule for use in views
      access_allow :authenticated_user, as: :can_see_data
      
      # Add a required rule for the whole controller
      access_require :basic_security, violation: :not_permitted
      
      # Rule implementations
      def allow_public?
        true
      end
      
      def allow_authenticated_user?(user)
        user.present?
      end
      
      def allow_admin?(user)
        user.try(:admin?)
      end
      
      def allow_basic_security?(user)
        true  # Always pass for testing
      end
      
      # Override controller attributes for testing
      attr_writer :action_name, :current_user
      
      def action_name
        @action_name || "index"
      end
      
      def current_user
        @current_user
      end
      
      # Method to expose access_allowed? for testing
      def check_view_permission(rule)
        access_allowed?(rule)
      end
    end
    
    # Create test users using the actual User class
    @admin_user = User.new(role: "admin")
    @regular_user = User.new(role: "regular")
    
    # Create a test permission
    @permission = Permission.new(ability_name: "test/ability1")
    
    # Set up association for test
    @regular_user.stubs(:permissions).returns([@permission])
    
    # Create controller instance
    @controller = @controller_class.new
  end
  
  teardown do
    # Restore original config
    AccessAllow.configure do |config|
      config.roles_and_permissions = @original_config
    end
  end
  
  # Test access manager configuration
  
  test "controller has access manager" do
    assert @controller_class.access_manager.is_a?(AccessAllow::AccessManager)
  end
  
  test "named rules are registered in access manager" do
    assert @controller_class.access_manager.named_rule_exists?(:index)
    assert @controller_class.access_manager.named_rule_exists?(:can_see_data)
  end
  
  # Test action access checking
  
  # Test named rule checking with access_allowed?
  
  test "access_allowed? checks named rules" do
    # Set current user
    @controller.current_user = @regular_user
    
    # Check a defined rule
    assert @controller.check_view_permission(:can_see_data)
    
    # Check non-existent rule
    refute @controller.check_view_permission(:non_existent)
  end
  
end