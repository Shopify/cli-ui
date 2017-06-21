require 'test_helper'

module Dev
  module UI
    class SpinnerTest < MiniTest::Test
      def test_spinner
        out, err = capture_io do
          Dev::UI::StdoutRouter.ensure_activated
          Dev::UI::Spinner.spin('sleeping') do
            sleep Dev::UI::Spinner::PERIOD * 2.5
          end
        end

        assert_equal('', err)
        match_lines(
          out,
          /⠋ sleeping/,
          /⠙/,
          /⠹/,
          /✓/
        )
      end

      def test_spinner_error
        out, err = capture_io do
          Dev::UI::StdoutRouter.ensure_activated
          Dev::UI::Spinner.spin('broken') do
            $stderr.puts 'not empty'
            raise 'some error'
          end
        end

        assert_equal('', err)
        match_lines(
          out,
          /⠋ broken/,
          /✗/,
          /┏━━ Task Failed: broken/,
          /┃ RuntimeError: some error/,
          /┃ \tfrom .*spinner_test/,
          /┃ \tfrom/,
          /┃ \tfrom/,
          /┃ \tfrom/,
          /┃ \tfrom/,
          /┣━━ STDOUT/,
          /┃ \(empty\)/,
          /┣━━ STDERR/,
          /┃ not empty/,
          /┗━━/
        )
      end

      private

      def printable(str)
        str.gsub(/\x1b\[[\d;]+\w/, '')
      end

      def match_lines(out, *patterns)
        # newline, or cursor-down
        lines = out.split(/\n|\x1b\[\d*B/)

        # Assert all lines are matched
        lines.each do |l|
          # strip ANSI colour code stuff
          line = Dev::UI::ANSI.strip_codes(l)
          assert patterns.any? { |p| line.match(p) }, "Nothing matched the line #{line}"
        end

        # Assert all patterns are matched
        patterns.each.with_index do |pattern, index|
          line = lines[index]
          # strip ANSI colour code stuff
          line.gsub!(/\x1b\[[\d;]+m/, '')
          assert_match(pattern, line)
        end
      end
    end
  end
end
