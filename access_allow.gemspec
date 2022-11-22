require_relative "lib/access_allow/version"

Gem::Specification.new do |spec|
  spec.name        = "access_allow"
  spec.version     = AccessAllow::VERSION
  spec.authors     = ["Stephen Ierodiaconou"]
  spec.email       = ["stevegeek@gmail.com"]
  spec.homepage    = "https://github.com/stevegeek/access_allow"
  spec.summary     = "Permissions and access control gem for Rails."
  spec.description = "Permissions and access control gem for Rails."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.4"
end
