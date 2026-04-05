# frozen_string_literal: true

require_relative "lib/rbdantic/version"

Gem::Specification.new do |spec|
  spec.name = "rbdantic"
  spec.version = Rbdantic::VERSION
  spec.authors = ["cp5670681"]
  spec.email = ["cp5670681@163.com"]

  spec.summary = "Pydantic-inspired data validation and serialization for Ruby"
  spec.description = "Rbdantic provides BaseModel-like data classes with field validation, type coercion, " \
                     "custom validators, JSON Schema generation, and serialization. Inspired by Python's Pydantic."
  spec.homepage = "https://github.com/cp5670681/rbdantic"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
