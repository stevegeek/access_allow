Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "application#index"

  get :logged_in, to: "application#logged_in"
  get :logged_in_with_ability, to: "application#logged_in_with_ability"
  get :logged_in_with_other_ability, to: "application#logged_in_with_other_ability"
end
