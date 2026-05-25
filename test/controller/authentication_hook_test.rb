require "test_helper"

# Verifies the optional `ensure_authenticated_before_perms_check` hook, which
# the DSL invokes (if defined) before running the permission check. Kept in its
# own controller so AccessControlTest can continue to exercise the branch where
# the hook is *not* defined.
class AuthenticationHookTest < ActionController::TestCase
  class HookController < ActionController::Base
    include AccessAllow::ControllerAccessDsl

    access_allow :public, to: :index

    def self.controller_path
      "hook"
    end

    def index
      render plain: "Public content"
    end

    def allow_public?
      true
    end

    def current_user
      nil
    end

    attr_reader :auth_hook_ran
    def ensure_authenticated_before_perms_check
      @auth_hook_ran = true
    end
  end

  tests HookController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "index", to: "hook#index"
    end
  end

  test "runs the authentication hook before the perms check when the controller defines it" do
    get :index
    assert_response :success
    assert @controller.auth_hook_ran, "expected the authentication hook to run during the request"
  end
end
