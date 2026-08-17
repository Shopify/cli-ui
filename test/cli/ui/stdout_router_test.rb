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

      def test_capture_opens_no_descriptors
        skip('/dev/fd unavailable') unless open_fds

        StdoutRouter::Capture.new {} # warm up any lazily-required files
        before = open_fds
        captures = Array.new(10) { StdoutRouter::Capture.new {} }

        assert_empty(open_fds - before)
        refute_empty(captures) # keep them reachable so nothing is finalized early
      end

      def test_capture_duplicate_output_to
        capture_io do
          StdoutRouter.with_enabled do
            dup = StringIO.new
            cap = StdoutRouter::Capture.new(duplicate_output_to: dup) { print('hello') }
            cap.run
            assert_equal('hello', cap.stdout)
            assert_equal('hello', dup.string)
            refute_predicate(dup, :closed?) # the capture doesn't own the handle
          end
        end
      end

      def test_capture_duplicate_output_to_receives_merged_stderr
        capture_io do
          StdoutRouter.with_enabled do
            dup = StringIO.new
            cap = StdoutRouter::Capture.new(merged_output: true, duplicate_output_to: dup) do
              $stderr.print('oops')
            end
            cap.run
            assert_equal('oops', dup.string)
          end
        end
      end

      def test_capture_ignores_closed_duplicate_output
        capture_io do
          StdoutRouter.with_enabled do
            dup = StringIO.new
            cap = StdoutRouter::Capture.new(duplicate_output_to: dup) do
              dup.close
              print('hello')
            end

            cap.run

            assert_equal('hello', cap.stdout)
          end
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
