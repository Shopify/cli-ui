# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class WrapTest < Minitest::Test
      def test_wrap
        para = 'Voluptatem consequatur ipsum. Totam omnis corrupti. Dignissimos esse repudiandae.'
        w = Wrap.new(para)

        ex = w.wrap(20)

        Terminal.stubs(:width).returns(20)
        assert_equal(ex, w.wrap)
      end

      def test_wrap_resends_active_codes_after_a_break
        wrapped = Wrap.new("\x1b[31maaaa bbbb cccc").wrap(9)

        assert_equal("\x1b[31maaaa bbbb\n\x1b[31mcccc", wrapped)
      end

      def test_wrap_stops_resending_codes_after_a_reset
        wrapped = Wrap.new("\x1b[31maaaa\x1b[0m bbbb cccc").wrap(9)

        assert_equal("\x1b[31maaaa\x1b[0m bbbb\ncccc", wrapped)
      end

      def test_wrap_detects_a_reset_hidden_in_a_parameter_list
        # \e[0;33m resets, then applies 33: earlier codes die at the reset
        # and only the survivors are resent after a break.
        wrapped = Wrap.new("\x1b[1m\x1b[0;33maaaa bbbb cccc").wrap(9)

        assert_equal("\x1b[1m\x1b[0;33maaaa bbbb\n\x1b[33mcccc", wrapped)
      end

      def test_wrap_detects_an_empty_parameter_as_a_reset
        # An empty SGR parameter (\e[;m) is a 0 to a terminal.
        wrapped = Wrap.new("\x1b[31maaaa\x1b[;m bbbb cccc").wrap(9)

        assert_equal("\x1b[31maaaa\x1b[;m bbbb\ncccc", wrapped)
      end

      def test_wrap_tracks_colon_form_sgr_codes
        wrapped = Wrap.new("\e[38:2::255:0:0maaaa bbbb cccc").wrap(9)

        assert_equal("\e[38:2::255:0:0maaaa bbbb\n\e[38:2::255:0:0mcccc", wrapped)
      end

      def test_wrap_keeps_sgr_replay_bounded
        input = 8.times.map { |i| "\e[#{31 + (i % 7)}m#{(97 + i).chr * 4}" }.join(' ')
        wrapped = Wrap.new(input).wrap(5)

        assert_equal([2, 2, 2, 2, 2, 2, 2, 1], wrapped.lines.map { |line| line.scan(/\e\[[\d;:]*m/).length })
        assert_operator(wrapped.bytesize, :<, input.bytesize * 2)
      end

      def test_wrap_reconstructs_independent_sgr_attributes
        wrapped = Wrap.new("\e[1m\e[31maaaa bbbb").wrap(4)

        assert_equal("\e[1m\e[31maaaa\n\e[1;31mbbbb", wrapped)
      end

      def test_wrap_groups_semicolon_form_extended_colors
        wrapped = Wrap.new("\e[1m\e[38;2;1;2;3maaaa bbbb").wrap(4)

        assert_equal("\e[1m\e[38;2;1;2;3maaaa\n\e[1;38;2;1;2;3mbbbb", wrapped)
      end

      def test_wrap_does_not_reinterpret_incomplete_extended_colors
        wrapped = Wrap.new("\e[38;2;255maaaa bbbb").wrap(4)

        assert_equal("\e[38;2;255maaaa\nbbbb", wrapped)
      end

      def test_wrap_deduplicates_parameters_in_last_used_order
        wrapped = Wrap.new("\e[1m\e[22m\e[1maaaa bbbb").wrap(4)

        assert_equal("\e[1m\e[22m\e[1maaaa\n\e[22;1mbbbb", wrapped)
      end

      def test_wrap_preserves_distinct_unrecognized_parameters
        wrapped = Wrap.new("\e[76m\e[77maaaa bbbb").wrap(4)

        assert_equal("\e[76m\e[77maaaa\n\e[76;77mbbbb", wrapped)
      end

      def test_wrap_reopens_a_hyperlink_after_a_break
        open_link = "\e]8;;https://example.com\e\\"
        close_link = ANSI::HYPERLINK_END
        wrapped = Wrap.new("#{open_link}aaaa bbbb cccc#{close_link}").wrap(9)

        assert_equal("#{open_link}aaaa bbbb#{close_link}\n#{open_link}cccc#{close_link}", wrapped)
      end
    end
  end
end
