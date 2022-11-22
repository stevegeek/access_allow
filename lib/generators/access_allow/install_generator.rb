# frozen_string_literal: true

require "rails/generators/base"
require "rails/generators/active_record/migration"

module AccessAllow
  module Generators
    # The Install generator `access_allow:install`
    class InstallGenerator < ::Rails::Generators::Base
      include ::ActiveRecord::Generators::Migration

      source_root File.expand_path(__dir__)

      desc "Creates an initial configuration, an initializer and copies in the Permission migration & model."

      def copy_tasks
        template "templates/access_allow.rb", "config/initializers/access_allow.rb"
        migration_template "templates/migration.rb", "db/migrate/access_allow_create_permissions.rb", migration_version: migration_version
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
