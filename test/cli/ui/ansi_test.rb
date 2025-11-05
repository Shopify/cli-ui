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

      def test_strip_codes_preserves_text_between_osc8_hyperlinks
        hyperlink = CLI::UI.link('https://example.com', 'text', format: false)
        input = "Before #{hyperlink} after"

        result = CLI::UI::ANSI.strip_codes(input)

        assert_equal('Before text after', result)
      end

      def test_strip_codes_with_osc9_progress_and_osc8_hyperlink
        # Test OSC 9 progress indicator (BEL-terminated) followed by OSC 8 hyperlink (ST-terminated)
        # This is the actual bug found in Ghostty terminal
        progress = "#{CLI::UI::ProgressReporter::Reporter::OSC}9;4;#{CLI::UI::ProgressReporter::Reporter::INDETERMINATE};#{CLI::UI::ProgressReporter::Reporter::ST}"
        hyperlink = CLI::UI.link('https://example.com/repo/pull/12345', 'PR#12345', format: false)
        input = "Before #{progress} Created #{hyperlink} After"

        result = CLI::UI::ANSI.strip_codes(input)

        # Should preserve all visible text
        assert_equal('Before  Created PR#12345 After', result)
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
