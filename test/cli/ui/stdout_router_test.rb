require 'test_helper'

module CLI
  module UI
    class StdoutRouterTest < MiniTest::Test
      def test_with_id
        out, _ = capture_io do
          StdoutRouter.with_enabled do
            StdoutRouter.with_id(on_streams: [$stdout]) do
              $stdout.puts "hello"
            end
          end
        end
        assert_match /\[\d{5}\] hello/, out
      end

      def test_with_id_with_argument_errors
        assert_raises ArgumentError do
          StdoutRouter.with_id(on_streams: ['a']) do
            $stdout.puts "hello"
          end
        end
      end
    end
  end
end
