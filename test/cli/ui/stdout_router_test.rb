# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module CLI
  module UI
    class StdoutRouterTest < Minitest::Test
      def test_with_id
        out, _ = capture_io do
          StdoutRouter.with_enabled do
            StdoutRouter.with_id(on_streams: [$stdout]) do
              $stdout.puts 'hello'
            end
          end
        end
        assert_match(/\[\d{5}\] hello/, out)
      end

      def test_current_id
        StdoutRouter.with_id(on_streams: [$stdout]) do |id|
          assert_equal({ id: id, streams: [$stdout] }, StdoutRouter.current_id)
        end
      end

      def test_frame_can_autoload_after_router_is_enabled
        script = <<~RUBY
          require 'stringio'
          require 'cli/ui'

          original_stdout = $stdout
          original_stderr = $stderr

          begin
            $stdout = StringIO.new
            $stderr = StringIO.new

            CLI::UI::StdoutRouter.enable
            $VERBOSE = true

            CLI::UI::Frame.open('Repro') { puts 'body' }
          ensure
            if defined?(CLI::UI::StdoutRouter) && CLI::UI::StdoutRouter.enabled?($stdout)
              CLI::UI::StdoutRouter.disable
            end
            $stdout = original_stdout
            $stderr = original_stderr
          end
        RUBY

        lib = File.expand_path('../../../lib', __dir__)
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', script)

        assert(status.success?, "stdout:\n#{stdout}\nstderr:\n#{stderr}")
      end
    end
  end
end
