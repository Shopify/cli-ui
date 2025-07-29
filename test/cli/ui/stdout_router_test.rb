# frozen_string_literal: true

require 'test_helper'

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

      def test_with_id_with_argument_errors
        skip('jruby runs without sorbet-runtime') if RUBY_ENGINE.include?('jruby')
        assert_raises(TypeError) do
          StdoutRouter.with_id(on_streams: ['a']) do
            $stdout.puts 'hello'
          end
        end
      end

      def test_current_id
        StdoutRouter.with_id(on_streams: [$stdout]) do |id|
          assert_equal({ id: id, streams: [$stdout] }, StdoutRouter.current_id)
        end
      end

      def test_flush_streams
        StdoutRouter.with_enabled do
          test_stream = StringIO.new
          test_stream.expects(:flush).once

          StdoutRouter.with_id(on_streams: [test_stream]) do
            writer = StdoutRouter::Writer.new($stdout, :stdout)
            writer.flush_streams
          end
        end
      end

      def test_flush_streams_handles_error
        StdoutRouter.with_enabled do
          closed_stream = StringIO.new
          closed_stream.expects(:flush).raises(IOError, 'closed stream').at_least_once

          device_failure_stream = StringIO.new
          device_failure_stream.expects(:flush).raises(Errno::ENOSPC, 'No space left on device').at_least_once

          working_stream = StringIO.new
          working_stream.expects(:flush).once

          StdoutRouter.with_id(on_streams: [closed_stream, device_failure_stream, working_stream]) do
            writer = StdoutRouter::Writer.new($stdout, :stdout)
            writer.flush_streams
          end
        end
      end
    end
  end
end
