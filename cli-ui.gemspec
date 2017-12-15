# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "cli/ui/version"

Gem::Specification.new do |spec|
  spec.name          = "cli-ui"
  spec.version       = CLI::UI::VERSION
  spec.authors       = ["Burke Libbey", "Julian Nadeau", "Lisa Ugray"]
  spec.email         = ["burke.libbey@shopify.com", "julian.nadeau@shopify.com", "lisa.ugray@shopify.com"]

  spec.summary       = 'Terminal UI framework'
  spec.description   = 'Terminal UI framework'
  spec.homepage      = "https://github.com/shopify/cli-ui"
  spec.license       = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
