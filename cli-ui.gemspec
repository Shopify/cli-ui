# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cli/ui/version'

Gem::Specification.new do |spec|
  spec.name          = 'cli-ui'
  spec.version       = CLI::UI::VERSION
  spec.authors       = ['Burke Libbey', 'Julian Nadeau', 'Lisa Ugray']
  spec.email         = ['burke.libbey@shopify.com', 'julian.nadeau@shopify.com', 'lisa.ugray@shopify.com']

  spec.summary       = 'Terminal UI framework'
  spec.description   = 'Terminal UI framework'
  spec.homepage      = 'https://github.com/shopify/cli-ui'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.rb', 'vendor/**/*', 'README.md', 'LICENSE.txt']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('zeitwerk', '~> 2.6.0')

  # spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency('minitest', '~> 5.0')
  spec.add_development_dependency('rake', '~> 13.0')
end
