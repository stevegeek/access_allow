require "test_helper"

class AccessAllow::RailtieTest < ActiveSupport::TestCase
  test "it inherits from Rails::Railtie" do
    assert_kind_of Rails::Railtie, AccessAllow::Railtie.instance
  end
end