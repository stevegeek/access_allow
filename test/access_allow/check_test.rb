require "test_helper"

class AccessAllow::CheckTest < ActiveSupport::TestCase
  setup do
    # Store original config
    @original_config = AccessAllow.configuration.roles_and_permissions.dup
    
    # Set up test config
    test_config = {
      user: {
        admin: { 
          namespace1: { ability1: true, ability2: false },
          namespace2: { ability3: true }
        }
      }
    }
    
    AccessAllow.configure do |config|
      config.roles_and_permissions = test_config
    end

    # Stub user and AbilitiesManager
    @user = stub('User')
    @user.stubs(:class).returns(stub('User class', name: 'User'))
    @user.stubs(:id).returns(1)
    @user.stubs(:send).returns([])
    
    # Rails logger mock
    Rails.stubs(:logger).returns(stub('Logger'))
    Rails.logger.stubs(:info)
    Rails.logger.stubs(:error)
  end

  teardown do
    # Restore original config
    AccessAllow.configure do |config|
      config.roles_and_permissions = @original_config
    end
  end

  test "call delegates to possible? method" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability1).returns(true)
    
    result = AccessAllow::Check.call(@user, namespace1: :ability1)
    assert result
  end

  test "call returns false when user is nil" do
    result = AccessAllow::Check.call(nil, namespace1: :ability1)
    refute result
  end

  test "call! delegates to possible! method" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability1).returns(true)
    
    result = AccessAllow::Check.call!(@user, namespace1: :ability1)
    assert result
  end

  test "call! raises ViolationError when permission check fails" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability2).returns(false)
    
    assert_raises AccessAllow::ViolationError do
      AccessAllow::Check.call!(@user, namespace1: :ability2)
    end
  end

  test "possible? returns false when user is nil" do
    check = AccessAllow::Check.new(nil, :namespace1, :ability1)
    refute check.possible?
  end

  test "possible? returns true when user has permission" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability1).returns(true)
    
    check = AccessAllow::Check.new(@user, :namespace1, :ability1)
    assert check.possible?
  end

  test "possible? returns false when user doesn't have permission" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability2).returns(false)
    
    check = AccessAllow::Check.new(@user, :namespace1, :ability2)
    refute check.possible?
  end

  test "possible! raises ViolationError when check fails" do
    abilities_manager = stub('AbilitiesManager')
    AccessAllow::AbilitiesManager.expects(:new).with(@user).returns(abilities_manager)
    abilities_manager.expects(:has?).with(:namespace1, :ability2).returns(false)
    
    check = AccessAllow::Check.new(@user, :namespace1, :ability2)
    assert_raises AccessAllow::ViolationError do
      check.possible!
    end
  end
end