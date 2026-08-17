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

      def test_nested_with_id_restores_outer_id
        StdoutRouter.with_id(on_streams: [$stdout]) do |outer_id|
          StdoutRouter.with_id(on_streams: [$stdout]) do |inner_id|
            assert_equal(inner_id, StdoutRouter.current_id&.fetch(:id))
          end
          assert_equal(outer_id, StdoutRouter.current_id&.fetch(:id))
        end
        assert_nil(StdoutRouter.current_id)
      end

      def test_nested_with_id_restores_outer_id_when_inner_raises
        StdoutRouter.with_id(on_streams: [$stdout]) do |outer_id|
          assert_raises(RuntimeError) do
            StdoutRouter.with_id(on_streams: [$stdout]) { raise('inner') }
          end
          assert_equal(outer_id, StdoutRouter.current_id&.fetch(:id))
        end
        assert_nil(StdoutRouter.current_id)
      end

      def test_capture_leaves_report_on_exception_untouched
        capture_io do
          StdoutRouter.with_enabled do
            prev = Thread.current.report_on_exception
            begin
              [true, false].each do |value|
                Thread.current.report_on_exception = value
                during = nil
                StdoutRouter::Capture.new { during = Thread.current.report_on_exception }.run
                assert_equal(value, during)
                assert_equal(value, Thread.current.report_on_exception)
              end
            ensure
              Thread.current.report_on_exception = prev
            end
          end
        end
      end

      def test_capture_failure_in_a_thread_still_reports_thread_death
        script = <<~RUBY
          require 'cli/ui'
          CLI::UI::StdoutRouter.enable
          thread = Thread.new { CLI::UI::StdoutRouter::Capture.new { raise('boom') }.run }
          begin
            thread.join
          rescue RuntimeError
            nil
          end
        RUBY

        lib = File.expand_path('../../../lib', __dir__)
        stdout, stderr, _ = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', script)

        assert_match(/terminated with exception/, stderr, "stdout:\n#{stdout}\nstderr:\n#{stderr}")
      end

      def test_nested_capture_restores_outer_capture
        capture_io do
          StdoutRouter.with_enabled do
            inner_current = nil
            restored_current = nil
            inner = StdoutRouter::Capture.new do
              inner_current = StdoutRouter::Capture.current_capture
            end
            outer = StdoutRouter::Capture.new do
              inner.run
              restored_current = StdoutRouter::Capture.current_capture
            end
            outer.run
            assert_same(inner, inner_current)
            assert_same(outer, restored_current)
            assert_nil(StdoutRouter::Capture.current_capture)
          end
        end
      end

      def test_nested_capture_restores_outer_capture_and_hook_when_inner_raises
        capture_io do
          StdoutRouter.with_enabled do
            restored_current = nil
            inner = StdoutRouter::Capture.new { raise('inner') }
            outer = StdoutRouter::Capture.new do
              assert_raises(RuntimeError) { inner.run }
              restored_current = StdoutRouter::Capture.current_capture
              puts('after inner')
            end
            outer.run
            assert_same(outer, restored_current)
            assert_includes(outer.stdout, 'after inner')
            assert_nil(StdoutRouter::Capture.current_capture)
          end
        end
      end

      def test_nested_capture_can_enter_alternate_screen
        capture_io do
          StdoutRouter.with_enabled do
            entered_alternate_screen = false
            outer = StdoutRouter::Capture.new do
              StdoutRouter::Capture.new {}.run
              StdoutRouter::Capture.in_alternate_screen do
                entered_alternate_screen = true
              end
            end

            outer.run

            assert(entered_alternate_screen)
          end
        end
      end

      def test_capture_restores_frame_inset_when_nested
        capture_io do
          StdoutRouter.with_enabled do
            inset_during_inner = nil
            inset_after_inner = nil
            inner = StdoutRouter::Capture.new(with_frame_inset: true) do
              inset_during_inner = Thread.current[:no_cliui_frame_inset]
            end
            outer = StdoutRouter::Capture.new(with_frame_inset: false) do
              inner.run
              inset_after_inner = Thread.current[:no_cliui_frame_inset]
            end
            outer.run
            assert_equal(false, inset_during_inner)
            assert_equal(true, inset_after_inner)
            assert_nil(Thread.current[:no_cliui_frame_inset])
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
