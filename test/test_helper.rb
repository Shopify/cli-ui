# frozen_string_literal: true

addpath = lambda do |p|
  path = File.expand_path("../../#{p}", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
addpath.call('lib')

require 'cli/ui'

# Otherwise, results will vary depending on the context in which we run tests.
CLI::UI.enable_color = true
CLI::UI.enable_cursor = true

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

  # Delete the file and any files under a dir of the same name to cover autoloaded children.
  delete_pattern = files.flat_map do |path|
    file = File.realpath(path)
    dir = file.delete_suffix('.rb')
    [Regexp.escape(file), "#{Regexp.escape(dir)}/.+"]
  end.join('|').then { |s| Regexp.new(s) }

  reset = proc do
    $LOADED_FEATURES.reject! do |feat|
      feat.match?(delete_pattern)
    end

    class_names.each { |classname| CLI::UI.send(:remove_const, classname) }
    files.each { |file| require(file) }
  end

  reset.call

  yield
ensure
  CLI::UI::OS.unstub(:current)
  reset.call
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
