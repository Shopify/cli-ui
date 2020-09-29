require 'test_helper'

module CLI
  module UI
    module Spinner
      class SpinGroupTest < MiniTest::Test
        def test_spin_group
          out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new
            sg.add('sleeping') do
              sleep(CLI::UI::Spinner::PERIOD * 2.5)
              true
            end

            assert(sg.wait)
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

        def test_spin_group_auto_debrief_false
          out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated

            sg = SpinGroup.new(auto_debrief: false)
            sg.add('sleeping') do
              sleep(CLI::UI::Spinner::PERIOD * 2.5)
              true
            end

            assert(sg.wait)
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

        private

        def match_lines(out, *patterns)
          # newline, or cursor-down
          lines = out.split(/\n|\x1b\[\d*B/)

          # Assert all patterns are matched
          assert_equal(patterns.size, lines.size)
          patterns.each_with_index do |pattern, index|
            line = CLI::UI::ANSI.strip_codes(lines[index])
            assert_match(pattern, line, "pattern number #{index} doesn't match line number #{index} in the output")
          end
        end
      end
    end
  end
end
