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

      def test_updating_title
        out, err = capture_io do
          Dev::UI::StdoutRouter.ensure_activated
          Dev::UI::Spinner.spin('私') do |task|
            assert task
            assert_respond_to task, :update_title
            sleep Dev::UI::Spinner::PERIOD * 2.5
            task.update_title '今日'
            sleep Dev::UI::Spinner::PERIOD * 2.5
            task.update_title '疲れたんだ'
            sleep Dev::UI::Spinner::PERIOD * 2.5
          end
        end

        assert_empty err
        match_lines(
          out,
          /⠋ 私/,
          /⠙/,
          /⠹/,
          /⠸ 今日/,
          /⠼/,
          /⠴ 疲れたんだ/,
          /⠦/,
          /⠧/,
          /✓/,
        )
      end

      def test_spinner_task_error_through_raising_exception
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

      def test_spinner_task_error_through_returning_error
        out, err = capture_io do
          Dev::UI::StdoutRouter.ensure_activated
          Dev::UI::Spinner.spin('broken') do
            $stderr.puts 'not empty'
            Dev::UI::Spinner::TASK_FAILED
          end
        end
        match_lines(
          out,
          /⠋ broken/,
          /✗/,
          /┏━━ Task Failed: broken/,
          /┣━━ STDOUT/,
          /┃ \(empty\)/,
          /┣━━ STDERR/,
          /┃ not empty/,
          /┗━━/,
        )
      end

      private

      def printable(str)
        str.gsub(/\x1b\[[\d;]+\w/, '')
      end

      def match_lines(out, *patterns)
        # newline, or cursor-down
        lines = out.split(/\n|\x1b\[\d*B/)

        # Assert all patterns are matched
        assert_equal patterns.size, lines.size
        patterns.each_with_index do |pattern, index|
          line = Dev::UI::ANSI.strip_codes(lines[index])
          assert_match(pattern, line, "pattern number #{index} doesn't match line number #{index} in the output")
        end
      end
    end
  end
end
