require "test_helper"

class AccessAllow::ControllerAccessDslTest < ActiveSupport::TestCase
  setup do
    # Mock Rails logger
    Rails.stubs(:logger).returns(stub('Logger'))
    Rails.logger.stubs(:info)
    Rails.logger.stubs(:error)
    
    # Create a test controller class
    @controller_class = Class.new(ActionController::Base) do
      include AccessAllow::ControllerAccessDsl
      
      # Define some test actions
      def index; end
      def show; end
      def edit; end
      
      # Define custom access rule method
      def allow_owner?(user)
        user&.id == 1
      end
    end
    
    # Configure base access rules
    @controller_class.access_allow(:public, to: :index)
    @controller_class.access_allow(:authenticated_user, to: :show)
    @controller_class.access_allow(:owner, to: :edit)
    @controller_class.access_allow(:admin, with: {admin: :manage}, as: :admin_view)
  end

  test "access_allow adds rules to the manager" do
    assert @controller_class.access_manager.named_rule_exists?(:index)
    assert @controller_class.access_manager.named_rule_exists?(:show)
    assert @controller_class.access_manager.named_rule_exists?(:edit)
    assert @controller_class.access_manager.named_rule_exists?(:admin_view)
  end

  test "access_no_match configures no match handling" do
    @controller_class.access_no_match(:redirect)
    assert_equal :redirect, @controller_class.access_manager.no_match_violation
  end

  test "access_require adds required rules" do
    # No direct way to test this without exposing internal state
    # This is an implicit test via testing full functionality
    @controller_class.access_require(:authenticated_user, violation: :not_permitted)
    assert @controller_class.access_manager.required_check_exists?(:authenticated_user)
  end

  test "each controller class has its own access_manager" do
    # Create a subclass
    subclass = Class.new(@controller_class) do
      access_allow(:admin, to: :new)
    end
    
    # Verify the subclass has its own rule
    assert subclass.access_manager.named_rule_exists?(:new)
  end

  test "subclass inherits parent class access rules" do
    # Create a subclass
    subclass = Class.new(@controller_class)
    
    # Verify the subclass has all the parent rules
    assert subclass.access_manager.named_rule_exists?(:index)
    assert subclass.access_manager.named_rule_exists?(:show)
    assert subclass.access_manager.named_rule_exists?(:edit)
    assert subclass.access_manager.named_rule_exists?(:admin_view)
  end

  test "access_allowed? delegate to access_manager" do
    controller = @controller_class.new
    user = stub('User')
    controller.stubs(:current_user).returns(user)
    
    # Mock access_manager.allow? to return true for admin_view
    @controller_class.access_manager.expects(:allow?).with([:admin_view], user, controller).returns(true)
    
    assert controller.access_allowed?(:admin_view)
  end

  test "handle_access_violation for severe violation" do
    controller = @controller_class.new
    controller.stubs(:current_user).returns(nil)
    controller.stubs(:controller_name).returns('test')
    controller.stubs(:action_name).returns('show')
    
    # Test :severe violation
    assert_raises ActionController::RoutingError do
      controller.send(:handle_access_violation, {violation: :severe})
    end
  end
  
  test "handle_access_violation for hidden violation" do
    controller = @controller_class.new
    controller.stubs(:current_user).returns(nil)
    controller.stubs(:controller_name).returns('test')
    controller.stubs(:action_name).returns('show')
    
    # Test :hidden violation
    assert_raises ActionController::RoutingError do
      controller.send(:handle_access_violation, {violation: :hidden})
    end
  end
  
  test "handle_access_violation for not_permitted violation" do
    controller = @controller_class.new
    controller.stubs(:current_user).returns(nil)
    controller.stubs(:controller_name).returns('test')
    controller.stubs(:action_name).returns('show')
    
    # Test :not_permitted violation
    assert_raises AccessAllow::ResponseForbiddenError do
      controller.send(:handle_access_violation, {violation: :not_permitted})
    end
  end
  
  test "handle_access_violation for redirect violation" do
    controller = @controller_class.new
    controller.stubs(:current_user).returns(nil)
    controller.stubs(:controller_name).returns('test')
    controller.stubs(:action_name).returns('show')
    controller.stubs(:root_path).returns('/root')
    controller.expects(:redirect_to).with('/root')
    
    controller.send(:handle_access_violation, {violation: :redirect})
  end
  
  test "handle_access_violation for redirect with custom handler" do
    controller = @controller_class.new
    controller.stubs(:current_user).returns(nil)
    controller.stubs(:controller_name).returns('test')
    controller.stubs(:action_name).returns('show')
    
    handler = ->{ '/custom_path' }
    controller.expects(:redirect_to).with('/custom_path')
    controller.send(:handle_access_violation, {violation: :redirect, handler: handler})
  end
  
  test "access_log_user_info formats user info for logs" do
    controller = @controller_class.new
    user = stub('User', id: 123)
    controller.stubs(:current_user).returns(user)
    
    assert_equal "User 123", controller.send(:access_log_user_info)
    
    # Test with nil user
    controller.stubs(:current_user).returns(nil)
    assert_equal "An unauthenticated user", controller.send(:access_log_user_info)
  end
  
  test "access_log_action_tried formats action info for logs" do
    controller = @controller_class.new
    controller.stubs(:controller_name).returns('posts')
    controller.stubs(:action_name).returns('show')
    
    assert_equal "posts#show", controller.send(:access_log_action_tried)
  end
end