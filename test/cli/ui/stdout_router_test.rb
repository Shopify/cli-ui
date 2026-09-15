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

      def test_write_without_cli_ui_constant_is_accessible
        assert_equal(:write_without_cli_ui, StdoutRouter::WRITE_WITHOUT_CLI_UI)
      end

      def test_writer_requires_the_original_write
        assert_raises(ArgumentError) do
          StdoutRouter::Writer.new(StringIO.new, :stdout)
        end
      end

      def test_router_can_reenable_after_disable
        capture_io do
          assert(StdoutRouter.enable)
          assert($stdout.respond_to?(:write_without_cli_ui))
          assert(StdoutRouter.disable)

          refute_predicate(StdoutRouter, :routed?)
          assert($stdout.respond_to?(:write_without_cli_ui))
          $stdout.write_without_cli_ui('bypassed')
          assert_equal('bypassed', $stdout.string)

          GC.start
          assert(StdoutRouter.enable)
          assert_predicate(StdoutRouter, :routed?)

          cap = StdoutRouter::Capture.new { print('hi') }
          cap.run
          assert_equal('hi', cap.stdout)
        ensure
          StdoutRouter.disable
        end
      end

      def test_capture_routes_its_current_streams
        capture_io do
          cap = StdoutRouter::Capture.new do
            $stdout.write('out')
            $stderr.write('err')
          end
          cap.run

          assert_equal('out', cap.stdout)
          assert_equal('err', cap.stderr)
          refute(StdoutRouter.routed?($stdout))
          refute(StdoutRouter.routed?($stderr))
        end
      end

      def test_capture_temporarily_routes_a_replaced_stderr
        capture_io do
          StdoutRouter.enable
          original_stderr = $stderr
          $stderr = StringIO.new

          cap = StdoutRouter::Capture.new do
            $stdout.write('out')
            $stderr.write('err')
          end
          cap.run

          assert_equal('out', cap.stdout)
          assert_equal('err', cap.stderr)
          assert(StdoutRouter.routed?($stdout))
          assert(StdoutRouter.routed?(original_stderr))
          refute(StdoutRouter.routed?($stderr))
        ensure
          StdoutRouter.disable
        end
      end

      def test_assert_enabled_requires_both_current_streams_to_be_routed
        capture_io do
          assert_raises(StdoutRouter::NotEnabled) { StdoutRouter.assert_enabled! }

          StdoutRouter.enable
          StdoutRouter.assert_enabled!
          StdoutRouter.disable($stderr)
          assert_raises(StdoutRouter::NotEnabled) { StdoutRouter.assert_enabled! }
        ensure
          StdoutRouter.disable
        end
      end

      def test_disable_leaves_only_the_compatibility_alias
        capture_io do
          StdoutRouter.enable
          StdoutRouter.disable

          assert_equal([:write_without_cli_ui], $stdout.singleton_methods)
          assert_equal([:write_without_cli_ui], $stderr.singleton_methods)
        end
      end

      def test_disable_restores_a_pre_existing_singleton_write
        capture_io do
          written = []
          $stdout.define_singleton_method(:write) do |*args|
            written << args.join
            super(*args)
          end

          StdoutRouter.enable
          $stdout.write('routed')
          StdoutRouter.disable
          $stdout.write('plain')

          assert_equal(['routed', 'plain'], written)
          assert_equal([:write, :write_without_cli_ui], $stdout.singleton_methods.sort)
        end
      end

      def test_enable_routes_a_stream_that_replaced_a_routed_one
        capture_io do
          StdoutRouter.enable
          original_stderr = $stderr
          $stderr = StringIO.new

          assert(StdoutRouter.enable)
          assert(StdoutRouter.routed?($stderr))
          assert(StdoutRouter.routed?(original_stderr))

          assert(StdoutRouter.disable(original_stderr))
          refute(StdoutRouter.routed?(original_stderr))
          refute(StdoutRouter.disable(original_stderr))

          assert(StdoutRouter.disable)
          refute_predicate(StdoutRouter, :routed?)
          refute(StdoutRouter.routed?($stderr))
        ensure
          StdoutRouter.disable
        end
      end

      def test_disable_unroutes_streams_replaced_in_globals
        capture_io do
          StdoutRouter.enable
          original_stdout = $stdout
          $stdout = StringIO.new

          assert(StdoutRouter.disable)
          refute(StdoutRouter.routed?(original_stdout))
          assert(original_stdout.respond_to?(:write_without_cli_ui))
          refute(StdoutRouter.routed?($stdout))
          assert_empty(StdoutRouter.routed_streams)
        ensure
          StdoutRouter.disable
        end
      end

      def test_enable_leaves_a_transiently_swapped_stream_routed
        capture_io do
          StdoutRouter.enable
          real_stdout = $stdout

          $stdout = StringIO.new
          StdoutRouter.ensure_activated
          $stdout = real_stdout

          assert(StdoutRouter.routed?(real_stdout))
          cap = StdoutRouter::Capture.new { print('still routed') }
          cap.run
          assert_equal('still routed', cap.stdout)
        ensure
          StdoutRouter.disable
        end
      end

      def test_scoped_routing_does_not_retain_previous_capture_streams
        previous_streams = nil
        capture_io_with_router do
          previous_streams = [$stdout, $stderr]
        end

        previous_streams.each { |stream| refute(StdoutRouter.routed?(stream)) }
        assert_empty(StdoutRouter.routed_streams)

        capture_io_with_router do
          previous_streams.each { |stream| refute(StdoutRouter.routed?(stream)) }
          assert_equal(2, StdoutRouter.routed_streams.size)
        end
        assert_empty(StdoutRouter.routed_streams)
      end

      def test_registry_does_not_retain_abandoned_routed_streams
        script = <<~RUBY
          require 'stringio'
          require 'cli/ui'

          def route_transient_streams
            original_stdout = $stdout
            original_stderr = $stderr
            $stdout = StringIO.new
            $stderr = StringIO.new
            CLI::UI::StdoutRouter.enable
          ensure
            $stdout = original_stdout
            $stderr = original_stderr
          end

          5.times { route_transient_streams }
          10.times { GC.start }
          abort("retained \#{CLI::UI::StdoutRouter.routed_streams.size} streams") unless
            CLI::UI::StdoutRouter.routed_streams.empty?
        RUBY

        lib = File.expand_path('../../../lib', __dir__)
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', lib, '-e', script)

        assert(status.success?, "stdout:\n#{stdout}\nstderr:\n#{stderr}")
      end

      def test_routed_streams_returns_a_snapshot
        capture_io do
          StdoutRouter.enable
          streams = StdoutRouter.routed_streams
          streams.clear

          assert_equal(2, StdoutRouter.routed_streams.size)
        ensure
          StdoutRouter.disable
        end
      end

      def test_enabled_remains_an_alias_for_routed_membership
        capture_io do
          refute_predicate(StdoutRouter, :routed?)
          refute_predicate(StdoutRouter, :enabled?)
          StdoutRouter.enable
          assert_predicate(StdoutRouter, :routed?)
          assert_predicate(StdoutRouter, :enabled?)
        ensure
          StdoutRouter.disable
        end
      end

      def test_compatibility_bypass_does_not_reenter_a_later_write_wrapper
        capture_io do
          StdoutRouter.enable
          StdoutRouter.disable

          calls = 0
          $stdout.define_singleton_method(:write) do |*args|
            calls += 1
            $stdout.write_without_cli_ui(*args)
          end

          $stdout.write('unrouted')
          StdoutRouter.enable
          $stdout.write('routed')

          assert_equal(2, calls)
          assert_equal('unroutedrouted', $stdout.string)
        ensure
          StdoutRouter.disable
        end
      end

      def test_public_bypass_does_not_reenter_a_later_write_wrapper
        capture_io do
          StdoutRouter.enable
          StdoutRouter.disable

          calls = 0
          stream = $stdout
          stream.define_singleton_method(:write) do |*args|
            calls += 1
            StdoutRouter.write_without_routing(stream, *args)
          end

          stream.write('unrouted')
          StdoutRouter.enable
          stream.write('routed')

          assert_equal(2, calls)
          assert_equal('unroutedrouted', stream.string)
        ensure
          StdoutRouter.disable
        end
      end

      def test_enable_handles_stderr_aliased_to_stdout
        capture_io do
          $stderr = $stdout

          assert(StdoutRouter.enable)
          assert(StdoutRouter.disable)
          assert_equal([:write_without_cli_ui], $stdout.singleton_methods)
        end
      end

      def test_enable_declines_a_stream_owned_by_another_router
        capture_io do
          original_write = $stderr.method(:write)
          previous_hook = Thread.current[:cliui_output_hook]
          hook_calls = 0
          $stderr.singleton_class.send(:define_method, :write_without_cli_ui, original_write)
          $stderr.define_singleton_method(:write) do |*args|
            Thread.current[:cliui_output_hook]&.call(args.join, :stderr)
            original_write.call(*args)
          end
          Thread.current[:cliui_output_hook] = ->(*) { hook_calls += 1 }

          refute(StdoutRouter.enable)
          refute(StdoutRouter.routed?($stdout))
          refute(StdoutRouter.routed?($stderr))

          $stderr.write('once')
          assert_equal(1, hook_calls)
          assert_equal('once', $stderr.string)
          refute(StdoutRouter.disable)
        ensure
          Thread.current[:cliui_output_hook] = previous_hook
          StdoutRouter.disable
        end
      end

      def test_enable_declines_a_foreign_marker_before_routing_any_stream
        capture_io do
          $stderr.singleton_class.send(:alias_method, :write_without_cli_ui, :write)

          refute(StdoutRouter.enable)
          assert_empty(StdoutRouter.routed_streams)
          assert($stderr.respond_to?(:write_without_cli_ui))
        ensure
          StdoutRouter.disable
        end
      end

      def test_enable_unroutes_only_streams_activated_before_a_failure
        capture_io do
          failing_stderr = StringIO.new
          failing_stderr.define_singleton_method(:define_singleton_method) do |name, *, &|
            raise "unexpected method: #{name}" unless name == :write

            raise 'cannot install write'
          end
          $stderr = failing_stderr

          error = assert_raises(RuntimeError) do
            StdoutRouter.enable
          end
          assert_equal('cannot install write', error.message)
          refute(StdoutRouter.routed?($stdout))
          refute(StdoutRouter.routed?($stderr))
          assert_empty(StdoutRouter.routed_streams)

          $stdout.write_without_cli_ui('unrouted')
          $stderr.write_without_cli_ui('also unrouted')
          assert_equal('unrouted', $stdout.string)
          assert_equal('also unrouted', $stderr.string)
        ensure
          StdoutRouter.disable
        end
      end

      def test_failed_enable_preserves_existing_routes
        capture_io do
          StdoutRouter.enable
          original_stderr = $stderr
          failing_stderr = StringIO.new
          failing_stderr.define_singleton_method(:define_singleton_method) do |name, *, &|
            raise "unexpected method: #{name}" unless name == :write

            raise 'cannot install write'
          end
          $stderr = failing_stderr

          error = assert_raises(RuntimeError) { StdoutRouter.enable }
          assert_equal('cannot install write', error.message)
          assert(StdoutRouter.routed?($stdout))
          assert(StdoutRouter.routed?(original_stderr))
          refute(StdoutRouter.routed?(failing_stderr))
        ensure
          StdoutRouter.disable
        end
      end

      def test_in_flight_writes_survive_disable
        capture_io do
          StdoutRouter.enable
          in_flight = $stdout.method(:write)
          StdoutRouter.disable

          in_flight.call('late')
          assert_includes($stdout.string, 'late')
        end
      end

      def test_write_without_routing_bypasses_the_router
        capture_io do
          StdoutRouter.enable
          cap = StdoutRouter::Capture.new { StdoutRouter.write_without_routing($stdout, 'bypass') }
          cap.run

          assert_equal('', cap.stdout)
          assert_includes($stdout.string, 'bypass')
        ensure
          StdoutRouter.disable
        end
      end

      def test_write_without_routing_falls_back_to_write_when_disabled
        capture_io do
          StdoutRouter.write_without_routing($stdout, 'unrouted')

          assert_includes($stdout.string, 'unrouted')
        end
      end

      def test_with_enabled_preserves_already_enabled_router
        capture_io do
          StdoutRouter.enable
          StdoutRouter.with_enabled {}

          assert_predicate(StdoutRouter, :routed?)
          cap = StdoutRouter::Capture.new { print('still routed') }
          cap.run
          assert_equal('still routed', cap.stdout)
        ensure
          StdoutRouter.disable
        end
      end

      def test_with_enabled_unroutes_only_what_it_routed
        capture_io do
          StdoutRouter.enable
          StdoutRouter.disable($stderr)

          StdoutRouter.with_enabled do
            assert(StdoutRouter.routed?($stdout))
            assert(StdoutRouter.routed?($stderr))
          end

          assert(StdoutRouter.routed?($stdout))
          refute(StdoutRouter.routed?($stderr))
        ensure
          StdoutRouter.disable
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
            if defined?(CLI::UI::StdoutRouter) && CLI::UI::StdoutRouter.routed?($stdout)
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
