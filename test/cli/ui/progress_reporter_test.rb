# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class ProgressReporterTest < Minitest::Test
      def setup
        # Mock environment to enable progress support for testing
        ENV.stubs(:[]).with('CLI_UI_ENABLE_PROGRESS').returns('1')
        ENV.stubs(:[]).with('ConEmuPID').returns(nil)
        ENV.stubs(:[]).with('WT_SESSION').returns(nil)
        ENV.stubs(:[]).with('GHOSTTY_RESOURCES_DIR').returns(nil)
        ENV.stubs(:[]).with('TERM_PROGRAM').returns(nil)
      end

      def test_with_progress_block
        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :progress, to: $stdout) do |reporter|
            reporter.set_progress(50)
          end
        end

        # Should output initial 0%, then 50%, then clear
        assert_match(/\e\]9;4;1;0\a/, out)
        assert_match(/\e\]9;4;1;50\a/, out)
        assert_match(/\e\]9;4;0;\a/, out)
      end

      def test_reporter_set_progress_clamping
        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :progress, to: $stdout) do |reporter|
            reporter.set_progress(150)
            reporter.set_progress(-10)
          end
        end

        # Should clamp to 100% and 0%
        assert_match(/\e\]9;4;1;100\a/, out)
        assert_match(/\e\]9;4;1;0\a/, out)
      end

      def test_reporter_set_indeterminate
        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :indeterminate, to: $stdout) do |reporter|
            # Indeterminate mode starts automatically
          end
        end

        # Should output OSC sequence for indeterminate progress and clear
        assert_match(/\e\]9;4;3;\a/, out)
        assert_match(/\e\]9;4;0;\a/, out)
      end

      def test_reporter_set_error
        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :progress, to: $stdout, &:set_error)
        end

        # Should output OSC sequence for error state
        assert_match(/\e\]9;4;2;\a/, out)
      end

      def test_reporter_set_paused
        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :progress, to: $stdout) do |reporter|
            reporter.set_paused(75)
            reporter.set_paused
          end
        end

        # Should output OSC sequences for paused states
        assert_match(/\e\]9;4;4;75\a/, out)
        assert_match(/\e\]9;4;4;\a/, out)
      end

      def test_supports_progress_with_conemu
        ENV.unstub(:[])
        ENV.stubs(:[]).returns(nil)
        ENV.stubs(:[]).with('ConEmuPID').returns('12345')

        assert(CLI::UI::ProgressReporter.supports_progress?)
      end

      def test_supports_progress_with_windows_terminal
        ENV.unstub(:[])
        ENV.stubs(:[]).returns(nil)
        ENV.stubs(:[]).with('WT_SESSION').returns('some-session')

        assert(CLI::UI::ProgressReporter.supports_progress?)
      end

      def test_supports_progress_with_ghostty
        ENV.unstub(:[])
        ENV.stubs(:[]).returns(nil)
        ENV.stubs(:[]).with('GHOSTTY_RESOURCES_DIR').returns('/path/to/resources')

        assert(CLI::UI::ProgressReporter.supports_progress?)
      end

      def test_supports_progress_with_term_program_ghostty
        ENV.unstub(:[])
        ENV.stubs(:[]).returns(nil)
        ENV.stubs(:[]).with('TERM_PROGRAM').returns('ghostty')

        assert(CLI::UI::ProgressReporter.supports_progress?)
      end

      def test_no_output_without_support
        ENV.unstub(:[])
        ENV.stubs(:[]).returns(nil)

        out, _ = capture_io do
          CLI::UI::ProgressReporter.with_progress(mode: :progress, to: $stdout) do |reporter|
            reporter.set_progress(50)
          end
        end

        # Should output nothing when progress is not supported
        assert_empty(out)
      end
    end
  end
end
