addpath = lambda do |p|
  path = File.expand_path("../../#{p}", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
addpath.call('lib')

require 'sorbet-runtime' unless RUBY_ENGINE.include?('jruby')
require 'cli/ui'

# Otherwise, results will vary depending on the context in which we run tests.
CLI::UI.enable_color = true

module CLI
  module UI
    class OS
      # Default to Mac behaviour so running the tests in different environments doesn't lead to different outputs
      def current
        CLI::UI::OS::MAC
      end
    end
  end
end

# Unloads the given classes from CLI::UI, reloads them and stubs the OS to the given one. This is used to run tests
# on classes with variables that depend on the OS (e.g. Glyph), so that we can mock their state in the context of this
# block.
def with_os_mock_and_reload(os, class_names = [], files = [])
  class_names = Array(class_names)
  files = Array(files)

  CLI::UI::OS.stubs(:current).returns(os)
  class_names.each { |classname| CLI::UI.send(:remove_const, classname) }
  files.each { |file| load(file) }

  yield
ensure
  CLI::UI::OS.unstub(:current)
  class_names.each { |classname| CLI::UI.send(:remove_const, classname) }
  files.each { |file| load(file) }
end

require 'fileutils'
require 'tmpdir'
require 'tempfile'

require 'rubygems'
require 'bundler/setup'

if RUBY_ENGINE !~ /jruby/
  require 'byebug'
end

require 'minitest/autorun'
require 'mocha/minitest'
