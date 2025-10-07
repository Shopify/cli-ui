# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class ANSITest < Minitest::Test
      def test_sgr
        assert_equal("\x1b[1;34m", ANSI.sgr('1;34'))
      end

      def test_printing_width
        assert_equal(4, ANSI.printing_width("\x1b[38;2;100;100;100mtest\x1b[0m"))
        assert_equal(0, ANSI.printing_width(''))

        assert_equal(3, ANSI.printing_width('>🔧<'))
        assert_equal(1, ANSI.printing_width('👩‍💻'))

        assert_equal(4, ANSI.printing_width(UI.link('url', 'text')))
      end

      def test_line_skip_with_shift
        next_line_expected = "\e[1B\e[1G"
        previous_line_expected = "\e[1A\e[1G"

        assert_equal(next_line_expected, ANSI.next_line)
        assert_equal(previous_line_expected, ANSI.previous_line)

        CLI::UI::OS.stubs(:current).returns(CLI::UI::OS::WINDOWS)

        assert_equal("#{next_line_expected}\e[1D", ANSI.next_line)
        assert_equal("#{previous_line_expected}\e[1D", ANSI.previous_line)
      end
    end
  end
end
