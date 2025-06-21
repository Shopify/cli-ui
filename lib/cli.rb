# typed: true
# frozen_string_literal: true

unless defined?(T)
  require('cli/ui/sorbet_runtime_stub')
end

require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  'ansi' => 'ANSI',
  'cli' => 'CLI',
  'os' => 'OS',
  'ui' => 'UI',
)
loader.setup

module CLI
end
