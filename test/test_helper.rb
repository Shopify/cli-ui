begin
  addpath = lambda do |p|
    path = File.expand_path("../../#{p}", __FILE__)
    $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
  end
  addpath.call("lib")
end

require 'cli/ui'

# Otherwise, results will vary depending on the context in which we run tests.
CLI::UI.enable_color = true

require 'fileutils'
require 'tmpdir'
require 'tempfile'

require 'rubygems'
require 'bundler/setup'

require 'byebug'

require 'minitest/autorun'
require 'mocha/minitest'
