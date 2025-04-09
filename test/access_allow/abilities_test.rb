require "test_helper"

class AccessAllow::AbilitiesTest < ActiveSupport::TestCase
  test "qualified_name returns properly formatted ability name" do
    result = AccessAllow::Abilities.qualified_name(:namespace, :ability)
    assert_equal "namespace/ability", result
  end

  test "qualified_name raises error when namespace or ability is blank" do
    assert_raises StandardError do
      AccessAllow::Abilities.qualified_name("", :ability)
    end

    assert_raises StandardError do
      AccessAllow::Abilities.qualified_name(:namespace, "")
    end
  end

  test "parse_qualified_name extracts namespace and ability correctly" do
    namespace, name = AccessAllow::Abilities.parse_qualified_name("namespace/ability")
    assert_equal :namespace, namespace
    assert_equal :ability, name
  end

  test "parse_qualified_name raises error with malformed input" do
    assert_raises StandardError do
      AccessAllow::Abilities.parse_qualified_name("invalid")
    end
  end

  test "parse_qualified_name raises error with too many parts" do
    assert_raises StandardError do
      AccessAllow::Abilities.parse_qualified_name("too/many/parts")
    end
  end

  test "humanized_name formats ability name for i18n" do
    I18n.expects(:t).with("abilities.user.abilities.namespace.ability").returns("Readable Ability")
    result = AccessAllow::Abilities.humanized_name(:user, :namespace, :ability)
    assert_equal "Readable Ability", result
  end
end