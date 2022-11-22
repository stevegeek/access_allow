# frozen_string_literal: true

AccessAllow.configure do |config|
  # Roles and permissions associated with each role (you might want to store this in a YAML file and load it here)
  config.roles_and_permissions = {}

  # config.current_user_method = :current_user
  # config.permissions_association_name = :permissions
  # config.role_method_name = :role
end
