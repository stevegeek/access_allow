# Start SimpleCov for test coverage
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/bin/"
  add_group "Library", "lib/"
  add_group "Generators", "lib/generators/"
  enable_coverage :branch
end

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
require "rails/test_help"
require "minitest/autorun"
require "minitest/mock"
require "mocha/minitest"

# Enable method stubbing in tests
module Minitest
  class Test
    # Add stubbing methods to all tests
    def stub_any_instance(klass, method, val_or_callable)
      klass.class_eval do
        alias_method :"original_#{method}", method
        define_method(method) do |*args|
          if val_or_callable.respond_to?(:call)
            val_or_callable.call(*args)
          else
            val_or_callable
          end
        end
      end

      yield
    ensure
      klass.class_eval do
        alias_method method, :"original_#{method}"
        remove_method :"original_#{method}"
      end
    end
  end
end

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end
