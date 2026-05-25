require "test_helper"

class AccessAllow::AccessManagerTest < ActiveSupport::TestCase
  # Plain object standing in for a controller. Custom rules are evaluated via
  # `instance_exec` on it, so it just needs to respond to the `allow_*?` methods.
  class FakeController
    def allow_zero_arity?
      true
    end

    def allow_one_arity?(user)
      user == :ok
    end

    def allow_two_arity?(user, info)
      info[:rule] == :two_arity && !user.nil?
    end
  end

  setup do
    @manager = AccessAllow::AccessManager.new
    @controller = FakeController.new
  end

  # --- configuration guards ---

  test "add_required_rule rejects an unknown violation type" do
    error = assert_raises StandardError do
      @manager.add_required_rule(:admin, :bogus, nil, nil)
    end
    assert_match(/valid violation type/, error.message)
  end

  test "add_allow_rule requires either actions or a name" do
    error = assert_raises StandardError do
      @manager.add_allow_rule(:admin, nil, nil, nil)
    end
    assert_match(/must specify the actions/, error.message)
  end

  # --- custom rule arities (apply_custom_rule) ---

  test "evaluates a zero-arity custom rule" do
    @manager.add_allow_rule(:zero_arity, :index)
    assert_equal true, @manager.allow_action?(:anyone, @controller, :index)
  end

  test "evaluates a two-arity custom rule, passing the rule info" do
    @manager.add_allow_rule(:two_arity, :show)
    assert_equal true, @manager.allow_action?(:someone, @controller, :show)
  end

  test "raises NotImplementedError for a custom rule with no matching method" do
    @manager.add_allow_rule(:nonexistent, :edit)
    assert_raises NotImplementedError do
      @manager.allow_action?(:anyone, @controller, :edit)
    end
  end

  # --- rule-set semantics ---

  test "an :any rule-set passes when any sub-rule passes" do
    @manager.add_allow_rule({any: [:one_arity, :zero_arity]}, :show)
    # one_arity fails for :nope, zero_arity passes -> :any succeeds
    assert_equal true, @manager.allow_action?(:nope, @controller, :show)
  end

  test "execute_rules_set raises on a rule set that is neither :all nor :any" do
    assert_raises NotImplementedError do
      @manager.send(:execute_rules_set, {bogus: []}, nil, :user, @controller, :index)
    end
  end

  test "a :to-all rule applies to every action" do
    @manager.add_allow_rule(:public, :all)
    assert_equal true, @manager.allow_action?(nil, @controller, :whatever)
  end

  test "no matching action rule returns the no-match violation" do
    @manager.add_allow_rule(:public, :index)
    assert_equal @manager.no_match_violation, @manager.allow_action?(nil, @controller, :missing)[:violation]
  end

  # --- required rules ---

  test "a failed required rule returns its violation and handler" do
    handler = -> { "/login" }
    @manager.add_required_rule(:authenticated_user, :redirect, nil, handler)
    @manager.add_allow_rule(:public, :index)

    result = @manager.allow_action?(nil, @controller, :index)
    assert_equal :redirect, result[:violation]
    assert_equal handler, result[:handler]
  end

  test "required rules that pass let action rules run" do
    @manager.add_required_rule(:authenticated_user, :severe, nil, nil)
    @manager.add_allow_rule(:public, :index)
    assert_equal true, @manager.allow_action?(:a_user, @controller, :index)
  end

  # --- introspection ---

  test "required_check_exists? finds checks in :all and :any required rules" do
    @manager.add_required_rule(:admin, :severe, nil, nil)
    @manager.add_required_rule({any: [:owner, :manager]}, :severe, nil, nil)

    assert @manager.required_check_exists?(:admin)
    assert @manager.required_check_exists?(:owner)
    refute @manager.required_check_exists?(:nobody)
  end

  # --- view-helper style named checks ---

  test "allow? evaluates named checks regardless of action" do
    @manager.add_allow_rule(:public, nil, nil, :always_ok)

    assert @manager.allow?([:always_ok], nil, @controller)
    assert @manager.allow?(:always_ok, nil, @controller)
    refute @manager.allow?([:undefined_check], nil, @controller)
  end

  test "the same named check can be registered by more than one rule" do
    @manager.add_allow_rule(:zero_arity, nil, nil, :shared)
    @manager.add_allow_rule(:one_arity, nil, nil, :shared)

    assert @manager.named_rule_exists?(:shared)
    # zero_arity passes for anyone, so the named check passes even though
    # one_arity would fail for :nope.
    assert @manager.allow?(:shared, :nope, @controller)
  end

  # --- no-match configuration ---

  test "configure_no_match stores a custom handler block" do
    @manager.configure_no_match(:redirect) { "/elsewhere" }
    assert_equal :redirect, @manager.no_match_violation
  end
end
