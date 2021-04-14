require 'test_helper'

module CLI
  module UI
    class SpinnerTest < MiniTest::Test
      def test_spinner
        out, err = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          CLI::UI::Spinner.spin('sleeping') do
          end
        end

        assert_equal('', err)
        assert_match(/sleeping/, out)
      end

      def test_async
        out, err = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          spinner = CLI::UI::Spinner::Async.start('sleeping')
          sleep(CLI::UI::Spinner::PERIOD * 2.5)
          spinner.stop
        end

        assert_equal('', err)
        assert_match(/sleeping/, out)
      end

      def test_updating_title
        out, err = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          CLI::UI::Spinner.spin('私') do |task|
            assert(task)
            assert_respond_to(task, :update_title)
            sleep(CLI::UI::Spinner::PERIOD * 2.5)
            task.update_title('今日')
            sleep(CLI::UI::Spinner::PERIOD * 2.5)
            task.update_title('疲れたんだ')
            sleep(CLI::UI::Spinner::PERIOD * 2.5)
          end
        end

        assert_empty(err)
        assert_match(/私/, out)
        assert_match(/今日/, out)
        assert_match(/疲れたんだ/, out)
      end

      def test_spinner_without_emojis
        with_os_mock_test do
          out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            spinner = CLI::UI::Spinner::Async.start('sleeping')
            sleep(CLI::UI::Spinner::PERIOD * 2.5)
            spinner.stop
          end

          assert_equal('', err)
          assert_match(/sleeping/, out)
          assert_match(/[\|\\\/]/, out)
          refute_match(/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/, out)
        end
      end

      def test_updating_title_without_emojis
        with_os_mock_test do
          out, err = capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            CLI::UI::Spinner.spin('私') do |task|
              assert(task)
              assert_respond_to(task, :update_title)
              sleep(CLI::UI::Spinner::PERIOD * 2.5)
              task.update_title('今日')
              sleep(CLI::UI::Spinner::PERIOD * 2.5)
              task.update_title('疲れたんだ')
              sleep(CLI::UI::Spinner::PERIOD * 2.5)
            end
          end

          assert_empty(err)
          assert_match(/私/, out)
          assert_match(/今日/, out)
          assert_match(/疲れたんだ/, out)
          assert_match(/[\|\\\/]/, out)
          refute_match(/[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]/, out)
        end
      end

      def test_spinner_task_error_through_raising_exception
        out, err = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          CLI::UI::Spinner.spin('broken') do
            sleep(CLI::UI::Spinner::PERIOD * 0.5)
            $stderr.puts 'not empty'
            raise 'some error'
          end
        end

        assert_equal('', err)
        assert_match(/✗/, out)
        assert_match(/RuntimeError: some error/, out)
        assert_match(/STDERR[^\n]*\n[^\n]*not empty/, out)
        assert_match(/STDOUT[^\n]*\n[^\n]*\(empty\)/, out)
      end

      def test_spinner_task_error_through_returning_error
        out, _ = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          CLI::UI::Spinner.spin('broken') do
            $stderr.puts 'not empty'
            sleep(CLI::UI::Spinner::PERIOD * 0.5)
            CLI::UI::Spinner::TASK_FAILED
          end
        end

        assert_match(/✗/, out)
        assert_match(/Task Failed: broken/, out)
        assert_match(/STDERR[^\n]*\n[^\n]*not empty/, out)
        assert_match(/STDOUT[^\n]*\n[^\n]*\(empty\)/, out)
      end

      private

      def with_os_mock_test
        classes = [:Spinner, :Glyph]

        root_path = File.join(File.dirname(__FILE__), '../../../lib/cli/ui')
        files = [
          File.join(root_path, 'spinner.rb'),
          File.join(root_path, 'glyph.rb'),
        ]

        Dir.glob(File.join(root_path, 'spinner', '*')).each do |file|
          files << file
        end

        with_os_mock_and_reload(CLI::UI::OS::Windows, classes, files) { yield }
      end
    end
  end
end
