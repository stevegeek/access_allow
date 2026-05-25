require "test_helper"

class AccessAllow::AbilitiesManagerTest < ActiveSupport::TestCase
  setup do
    # Store original config
    @original_config = AccessAllow.configuration.roles_and_permissions.dup
    @original_association = AccessAllow.configuration.permissions_association_name
    @original_role_method = AccessAllow.configuration.role_method_name

    # Set up test config
    test_config = {
      user: {
        admin: {
          namespace1: {ability1: true, ability2: false},
          namespace2: {ability3: true}
        },
        staff: {
          namespace1: {ability1: false, ability2: true},
          namespace2: {ability3: false}
        },
        primary: {
          namespace1: {ability1: true}
        }
      }
    }

    AccessAllow.configure do |config|
      config.roles_and_permissions = test_config
      config.permissions_association_name = :permissions
      config.role_method_name = :role
    end

    # Create stub user
    @user = stub("User")
    @user.stubs(:class).returns(stub("User class", name: "User"))
    @user.stubs(:id).returns(1)

    # Mock user role
    @user.stubs(:role).returns("admin")

    # Mock permission records
    permission1 = stub("Permission")
    permission1.stubs(:ability_name).returns("namespace1/ability2")
    @user.stubs(:permissions).returns([permission1])
  end

  teardown do
    # Restore original config
    AccessAllow.configure do |config|
      config.roles_and_permissions = @original_config
      config.permissions_association_name = @original_association
      config.role_method_name = @original_role_method
    end
  end

  test "has? returns true for permitted abilities from role" do
    manager = AccessAllow::AbilitiesManager.new(@user)
    assert manager.has?(:namespace1, :ability1)
    assert manager.has?(:namespace2, :ability3)
  end

  test "has? returns false for non-permitted abilities from role" do
    # Override permissions to return an empty array for this test
    @user.stubs(:permissions).returns([])
    manager = AccessAllow::AbilitiesManager.new(@user)
    refute manager.has?(:namespace1, :ability2)
  end

  test "has? overrides role abilities with user-specific permissions" do
    # The user has namespace1/ability2 explicitly granted through permissions
    manager = AccessAllow::AbilitiesManager.new(@user)
    assert manager.has?(:namespace1, :ability2)
  end

  test "has? raises error for unknown namespace" do
    manager = AccessAllow::AbilitiesManager.new(@user)
    assert_raises StandardError do
      manager.has?(:unknown_namespace, :ability1)
    end
  end

  test "to_a returns array of permitted abilities" do
    manager = AccessAllow::AbilitiesManager.new(@user)
    abilities = manager.to_a

    assert_includes abilities, [:namespace1, :ability1]
    assert_includes abilities, [:namespace1, :ability2] # Overridden by user permission
    assert_includes abilities, [:namespace2, :ability3]

    # Should have exactly 3 abilities
    assert_equal 3, abilities.size
  end

  test "handles different user roles" do
    @user.stubs(:role).returns("staff")
    # Clear specific permissions for this test
    @user.stubs(:permissions).returns([])

    manager = AccessAllow::AbilitiesManager.new(@user)
    refute manager.has?(:namespace1, :ability1)
    assert manager.has?(:namespace1, :ability2)
    refute manager.has?(:namespace2, :ability3)
  end

  test "uses default 'primary' role when user role is blank" do
    @user.stubs(:role).returns(nil)
    @user.stubs(:permissions).returns([])

    manager = AccessAllow::AbilitiesManager.new(@user)
    assert manager.has?(:namespace1, :ability1)
  end

  # The abilities are resolved lazily on the first `has?`, so the guard
  # errors surface there rather than from the constructor.
  test "raises when the user type has no permissions defined" do
    @user.stubs(:class).returns(stub("UnknownClass", name: "UnknownClass"))
    manager = AccessAllow::AbilitiesManager.new(@user)

    error = assert_raises StandardError do
      manager.has?(:namespace1, :ability1)
    end
    assert_match(/User type/, error.message)
  end

  test "raises when the user role has no permissions defined" do
    AccessAllow.configure do |config|
      config.roles_and_permissions = {user: {staff: {namespace1: {ability1: true}}}}
    end
    @user.stubs(:role).returns("nonexistent_role")
    @user.stubs(:permissions).returns([])
    manager = AccessAllow::AbilitiesManager.new(@user)

    error = assert_raises StandardError do
      manager.has?(:namespace1, :ability1)
    end
    assert_match(/Role/, error.message)
  end

  test "user-assigned permissions for abilities absent from the role are ignored" do
    unknown = stub("Permission")
    unknown.stubs(:ability_name).returns("namespace2/not_in_role")
    @user.stubs(:permissions).returns([unknown])

    manager = AccessAllow::AbilitiesManager.new(@user)
    # The ability was never in the role, so the assignment is dropped and it
    # resolves to nil (not granted); role-derived abilities are unaffected.
    assert_nil manager.has?(:namespace2, :not_in_role)
    assert manager.has?(:namespace1, :ability1)
  end

  test "to_a lists only permitted abilities" do
    manager = AccessAllow::AbilitiesManager.new(@user)
    pairs = manager.to_a
    assert_includes pairs, [:namespace1, :ability1]
    assert_includes pairs, [:namespace2, :ability3]
    # ability2 is false in the role but granted via the user permission record
    assert_includes pairs, [:namespace1, :ability2]
  end

  test "to_a omits abilities that are not permitted" do
    @user.stubs(:role).returns("staff")
    @user.stubs(:permissions).returns([])
    manager = AccessAllow::AbilitiesManager.new(@user)
    pairs = manager.to_a
    # staff role: namespace1 {ability1: false, ability2: true}, namespace2 {ability3: false}
    assert_includes pairs, [:namespace1, :ability2]
    refute_includes pairs, [:namespace1, :ability1]
    refute_includes pairs, [:namespace2, :ability3]
  end
end
