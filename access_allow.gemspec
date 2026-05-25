require_relative "lib/access_allow/version"

Gem::Specification.new do |spec|
  spec.name = "access_allow"
  spec.version = AccessAllow::VERSION
  spec.authors = ["Stephen Ierodiaconou"]
  spec.email = ["stevegeek@gmail.com"]
  spec.homepage = "https://github.com/stevegeek/access_allow"
  spec.summary = "Permissions and access control gem for Rails."
  spec.description = "Role- and ability-based authorization for Rails controllers, " \
    "with a declarative DSL for allow/require rules, named checks and configurable access violations."
  spec.license = "MIT"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 7.2", "< 9"
  spec.required_ruby_version = ">= 3.2.0"
end
