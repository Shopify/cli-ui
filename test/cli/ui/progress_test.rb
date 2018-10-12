require 'test_helper'

module CLI
  module UI
    class ProgressTest < MiniTest::Test
      def test_tick_with_percent
        assert_bar(set_percent: 0.1, expected_filled: 1, expected_unfilled: 9, suffix: ' 10.0%')
      end

      def test_tick_with_set_percent
        assert_bar(set_percent: 0.9, expected_filled: 9, expected_unfilled: 1, suffix: ' 90.0%')
      end

      def test_tick_with_set_percent_above_100_percent_is_set_to_100_percent
        assert_bar(set_percent: 2.0, expected_filled: 10, suffix: ' 100.0%')
      end

      def test_tick_with_percent_change_to_above_100_percent_is_set_to_100_percent
        assert_bar(percent: 2.0, expected_filled: 10, suffix: ' 100.0%')
      end

      def test_tick_with_set_percent_and_percent_raises
        assert_raises ArgumentError do
          bar = Progress.new(width: 10)
          bar.tick(percent: 0.5, set_percent: 0.9)
        end
      end

      def assert_bar(percent: nil, set_percent: nil, expected_filled: 0, expected_unfilled: 0, suffix: '')
        expected_bar = "\e[0m\e[46m#{' ' * expected_filled}\e[1;47m#{' ' * expected_unfilled}\e[0m#{suffix}"

        params = {}
        params[:percent] = percent if percent
        params[:set_percent] = set_percent if set_percent

        out, = capture_io do
          bar = Progress.new(width: 10 + suffix.size) # each 10% is one box with this width
          bar.tick(params)
          assert_equal expected_bar, bar.to_s
        end

        assert_equal expected_bar + "\e[1A\e[1G\n", out
      end
    end
  end
end
