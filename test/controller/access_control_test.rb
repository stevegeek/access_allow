require "test_helper"

# This test demonstrates testing access control via controller actions
class AccessControlTest < ActionController::TestCase
  class TestsController < ActionController::Base
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
    
    # Set up routes for testing
    def self.controller_path
      "tests"
    end
    
    # Actions with default responses
    def index
      render plain: "Public content"
    end
    
    def show
      render plain: "Authenticated content"
    end
    
    def admin
      render plain: "Admin content"
    end
    
    def special
      render plain: "Special content"
    end
    
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
    
    # Method to check view permissions
    def check_view_permission(rule)
      access_allowed?(rule)
    end
    
    # Override current_user to use our test user
    attr_accessor :current_test_user
    def current_user
      current_test_user
    end
  end
  
  # Set controller for testing
  tests TestsController
  
  setup do
    # Configure access control for testing
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
    
    # Create test users
    @admin_user = User.create!(role: "admin")
    @regular_user = User.create!(role: "regular")
    
    # Add permissions to the regular user
    @permission = Permission.create!(user: @regular_user, ability_name: "test/ability1")
    
    # Set up routes for testing
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get 'index', to: 'tests#index'
      get 'show', to: 'tests#show'
      get 'admin', to: 'tests#admin'
      get 'special', to: 'tests#special'
    end
  end
  
  teardown do
    # Restore default config
    AccessAllow.configure do |config|
      config.roles_and_permissions = {
        user: {
          owner: { test: { ability1: true } }
        }
      }
    end
  end
  
  # Test public access
  test "allows public access to index without user" do
    @controller.current_test_user = nil
    get :index
    assert_response :success
    assert_equal "Public content", response.body
  end
  
  # Test authenticated access
  test "requires authentication for show action" do
    # Without user
    @controller.current_test_user = nil
    assert_raises(ActionController::RoutingError) do
      get :show
    end
    
    # With user
    @controller.current_test_user = @regular_user
    get :show
    assert_response :success
    assert_equal "Authenticated content", response.body
  end
  
  # Test role-based access
  test "restricts admin action to admin users" do
    # Regular user
    @controller.current_test_user = @regular_user
    assert_raises(ActionController::RoutingError) do
      get :admin
    end
    
    # Admin user
    @controller.current_test_user = @admin_user
    get :admin
    assert_response :success
    assert_equal "Admin content", response.body
  end
  
  # Test permission-based access
  test "allows access based on permissions" do
    # Regular user with permission
    @controller.current_test_user = @regular_user
    get :special
    assert_response :success
    assert_equal "Special content", response.body
    
    # Remove permission
    @permission.destroy
    
    # Regular user without permission
    @controller.current_test_user = @regular_user.reload
    assert_raises(ActionController::RoutingError) do
      get :special
    end
  end
  
  # Test checking named rules
  test "allows checking named rules in views" do
    # Without user
    @controller.current_test_user = nil
    refute @controller.check_view_permission(:can_see_data)
    
    # With user
    @controller.current_test_user = @regular_user
    assert @controller.check_view_permission(:can_see_data)
  end
end