# frozen_string_literal: true

AccessAllow.configure do |config|
  # Roles and permissions associated with each role (you might want to store this in a YAML file and load it here)
  config.roles_and_permissions = {}

  # config.current_user_method = :current_user
  # config.permissions_association_name = :permissions
  # config.role_method_name = :role

  # Logger used for access logging. Defaults to Rails.logger.
  # config.logger = Rails.logger

  # Level for the per-check "user cannot do X" lines. These fire on every
  # failed ability check and are normal control flow (menu visibility,
  # scoping), so they default to :debug. Set to nil to silence them entirely.
  # Actual access violations are always logged at :info/:error.
  # config.permission_check_log_level = :debug
end
