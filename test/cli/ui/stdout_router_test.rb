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

      def test_current_id
        StdoutRouter.with_id(on_streams: [$stdout]) do |id|
          assert_equal({ id: id, streams: [$stdout] }, StdoutRouter.current_id)
        end
      end
    end
  end
end
