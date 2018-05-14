require 'test_helper'

module CLI
  module UI
    class StdoutRouterTest < MiniTest::Test
      def test_with_uuid
        out, _ = capture_io do
          StdoutRouter.with_enabled do
            StdoutRouter.with_uuid(on_streams: [$stdout]) do
              $stdout.puts "hello"
            end
          end
        end
        assert_match /\[\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\] hello/, out
      end

      def test_with_uuid_with_argument_errors
        assert_raises ArgumentError do
          StdoutRouter.with_uuid(on_streams: ['a']) do
            $stdout.puts "hello"
          end
        end
      end
    end
  end
end
