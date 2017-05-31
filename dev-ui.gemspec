# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "dev/ui/version"

Gem::Specification.new do |spec|
  spec.name          = "dev-ui"
  spec.version       = Dev::UI::VERSION
  spec.authors       = ["Burke Libbey"]
  spec.email         = ["burke@libbey.me"]

  spec.summary       = %q{Terminal UI framework}
  spec.description   = %q{Terminal UI framework}
  spec.homepage      = "https://github.com/shopify/dev-ui"
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
