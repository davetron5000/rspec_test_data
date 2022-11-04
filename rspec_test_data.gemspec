require_relative "lib/rspec_test_data/version"

Gem::Specification.new do |spec|
  spec.name = "rspec_test_data"
  spec.version = RspecTestData::VERSION
  spec.authors       = ["Dave Copeland"]
  spec.email         = ["davec@naildrivin5.com"]
  spec.summary       = %q{Create complex sets of test data using factories to allow re-use across tests or in seed data}
  spec.homepage      = "https://sustainable-rails.com"
  spec.license       = "Hippocratic"

  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sustainable-rails/rspec_test_data"
  spec.metadata["changelog_uri"] = "https://github.com/sustainable-rails/rspec_test_data/releases"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency("rspec")
  spec.add_development_dependency("rspec_junit_formatter")
end
