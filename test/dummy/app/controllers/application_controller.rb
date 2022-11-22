class ApplicationController < ActionController::Base
  include AccessAllow::ControllerAccessDsl

  access_allow :public, to: :index
  access_allow :authenticated_user, to: :logged_in, as: :logged_in_user
  access_allow :authenticated_user, with: {test: :ability1}, to: :logged_in_with_ability
  access_allow :authenticated_user, with: {test: :ability2}, to: :logged_in_with_other_ability

  attr_reader :current_user

  prepend_before_action :log_in

  def log_in
    @current_user = User.first if params[:login]
  end

  def index
    render plain: "Hello World #{access_allowed?(:logged_in_user) ? "logged in" : "not logged in"}"
  end

  def logged_in
    render plain: "Hello user!"
  end

  def logged_in_with_ability
    render plain: "Hello user with ability!"
  end

  def logged_in_with_other_ability
    render plain: "Hello user with other ability!"
  end
end
