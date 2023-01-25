# coding: utf-8

require 'test_helper'
require 'readline'
require 'timeout'
require 'open3'

module CLI
  module UI
    class PromptTest < Minitest::Test
      # ^C is not handled; raises Interrupt, which may be handled by caller.
      def test_confirm_sigint
        jruby_skip('SIGINT shuts down the JVM instead of raising Interrupt')

        run_in_process(<<~RUBY)
          begin
            CLI::UI::Prompt.confirm('question')
          rescue Interrupt
            puts 'sentinel'
          end
        RUBY

        wait_for_output_to_include('question')
        kill_process

        assert_output_includes('sentinel')
      end

      # ^C is not handled; raises Interrupt, which may be handled by caller.
      def test_ask_free_form_sigint
        jruby_skip('SIGINT shuts down the JVM instead of raising Interrupt')

        run_in_process(<<~RUBY)
          begin
            CLI::UI::Prompt.ask('question')
          rescue Interrupt
            puts 'sentinel'
          end
        RUBY

        wait_for_output_to_include('question')
        kill_process

        assert_output_includes('sentinel')
      end

      # ^C is not handled; raises Interrupt, which may be handled by caller.
      def test_ask_interactive_sigint
        jruby_skip('SIGINT shuts down the JVM instead of raising Interrupt')

        run_in_process(<<~RUBY)
          begin
            CLI::UI::Prompt.ask('question', options: %w(a b))
          rescue Interrupt
            puts 'sentinel'
          end
        RUBY

        wait_for_output_to_include('question')
        kill_process

        assert_output_includes('sentinel')
      end

      def test_confirm_happy_path
        run_in_process('puts CLI::UI::Prompt.confirm("q")')
        write('y')
        assert_output_includes('true')
      end

      def test_confirm_default_no
        run_in_process('puts CLI::UI::Prompt.confirm("q", default: false)')
        write("\n")
        assert_output_includes('false')
      end

      def test_confirm_invalid
        run_in_process('puts CLI::UI::Prompt.confirm("q")')
        write('ryn')
        assert_output_includes('true')
      end

      def test_confirm_no_match_internal
        run_in_process('puts CLI::UI::Prompt.confirm("q", default: false)')
        write('xn')
        assert_output_includes('false')
      end

      def test_output_includes_instructions
        run_in_process('CLI::UI::Prompt.confirm("q")')
        write('y')
        assert_output_includes('(Choose with ↑ ↓ ⏎)')
      end

      def test_windows_instructions
        # Windows doesn't detect presses on the arrow keys when picking an option, so we don't show the instruction text
        # for them.
        run_in_process(<<~RUBY)
          CLI::UI::OS # Force the file to load before redefining ::current
          module CLI
            module UI
              class OS
                def self.current
                  CLI::UI::OS::WINDOWS
                end
              end
            end
          end
          CLI::UI::Prompt.confirm("q")
        RUBY
        write('y')
        assert_output_includes("(Navigate up with 'k' and down with 'j', press Enter to select)")
      end

      def test_ask_free_form_happy_path
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q")}--"')
        write("asdf\n")
        assert_output_includes('--asdf--')
      end

      def test_ask_free_form_empty_answer_allowed
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q")}--"')
        write("\n")
        assert_output_includes('----')
      end

      def test_ask_free_form_empty_answer_rejected
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", allow_empty: false)}--"')
        write("\nasdf\n")
        assert_output_includes('--asdf--')
      end

      def test_ask_free_form_no_filename_completion
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q")}--"')
        write("/dev/nul\t\n")
        assert_output_includes('--/dev/nul--')
      end

      def test_ask_free_form_filename_completion
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", is_file: true)}--"')
        write("/dev/nul\t\n")
        assert_output_includes('--/dev/null--')
      end

      def test_ask_free_form_default
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", default: "asdf")}--"')
        write("\n")
        assert_output_includes('--asdf--')
      end

      def test_ask_free_form_default_nondefault
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", default: "asdf")}--"')
        write("zxcv\n")
        assert_output_includes('--zxcv--')
      end

      def test_ask_invalid_kwargs
        error = assert_raises(ArgumentError) { Prompt.ask('q', options: ['a'], default: 'a') }
        assert_equal('conflicting arguments: default may not be provided with options when not multiple', error.message)

        error = assert_raises(ArgumentError) { Prompt.ask('q', options: ['a'], is_file: true) }
        assert_equal('conflicting arguments: is_file is only useful when options are not provided', error.message)

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', default: 'a', allow_empty: false)
        end
        assert_equal('conflicting arguments: default enabled but allow_empty is false', error.message)

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', default: 'b') {}
        end
        assert_equal('conflicting arguments: default may not be provided with options when not multiple', error.message)
      end

      def test_ask_interactive_conflicting_arguments
        error = assert_raises(ArgumentError) do
          Prompt.ask('q', options: ['a', 'b']) { |h| h.option('a') }
        end
        assert_equal('conflicting arguments: options and block given', error.message)

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', options: ['a', 'b'], multiple: true, default: ['b', 'c']) { |h| h.option('a') }
        end
        assert_equal('conflicting arguments: default should only include elements present in options', error.message)
      end

      def test_ask_interactive_insufficient_options
        exception = assert_raises(ArgumentError) do
          Prompt.ask('q', options: [])
        end
        assert_equal('insufficient options', exception.message)

        exception = assert_raises(ArgumentError) do
          Prompt.ask('q') { |_h| {} }
        end
        assert_equal('insufficient options', exception.message)
      end

      def test_ask_interactive_with_block
        run_in_process(<<~RUBY)
          puts(CLI::UI::Prompt.ask('q') do |h|
            h.option('a') { |_a| 'a was selected' }
            h.option('b') { |_a| 'b was selected' }
          end)
        RUBY
        write('1')

        assert_output_includes('a was selected')
      end

      def test_ask_interactive_with_vim_bound_arrows
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", options: %w(a b))}--"')
        write('j ')
        assert_output_includes('--b--')
      end

      def test_ask_interactive_escape
        run_in_process(<<~RUBY)
          begin
            CLI::UI::Prompt.ask("q", options: %w(a b))
          rescue Interrupt # jruby can rescue this one since we raise it rather than receiving it as a signal
            puts 'sentinel'
          end
        RUBY

        write("\e;")
        assert_output_includes('sentinel')
      end

      def test_ask_interactive_invalid_input
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", options: %w(a b))}--"')
        write('3nan2')
        assert_output_includes('--b--')
      end

      def test_ask_interactive_with_blank_option
        run_in_process(<<~RUBY)
          puts(CLI::UI::Prompt.ask('q') do |h|
            h.option('a') { |_a| 'a was selected' }
            h.option('') { |_a| 'b was selected' }
          end)
        RUBY
        write('jj ')
        assert_output_includes('a was selected')
      end

      def test_ask_interactive_filter_options
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", options: %w(abcd xyz))}--"')
        write("fz\n")
        assert_output_includes('--xyz--')
      end

      def test_ask_interactive_line_selection
        run_in_process('puts "--#{CLI::UI::Prompt.ask("q", options: (1..15).map(&:to_s))}--"')
        write("e10\n")
        assert_output_includes('--10--')
      end

      def test_ask_multiple
        run_in_process('puts CLI::UI::Prompt.ask("q", options: (1..15).map(&:to_s), multiple: true).inspect')
        write('1350')
        assert_output_includes(['1', '3', '5'].inspect)
      end

      def test_ask_multiple_with_handler
        run_in_process(<<~RUBY)
          puts(CLI::UI::Prompt.ask('q', multiple: true) do |handler|
            ('1'..'10').each do |i|
              handler.option(i) { i }
            end
          end.inspect)
        RUBY
        write('1350')
        assert_output_includes(['1', '3', '5'].inspect)
      end

      def test_ask_multiple_with_default_values
        run_in_process(
          'puts CLI::UI::Prompt.ask("q", options: (1..15).map(&:to_s), multiple: true, default: %w(2 3)).inspect',
        )
        write('120')
        assert_output_includes(['1', '3'].inspect)
      end

      def test_any_key_presents_a_default_message_and_waits_for_any_key
        run_in_process('p CLI::UI::Prompt.any_key')
        write('c')
        assert_output_includes("Press any key to continue...\n#{"c".inspect}")
      end

      def test_any_key_allows_a_custom_message
        run_in_process('p CLI::UI::Prompt.any_key("Where is the any key?")')
        write('c')
        assert_output_includes("Where is the any key?\n#{"c".inspect}")
      end

      def test_any_key_allows_for_capturing_return
        run_in_process('p CLI::UI::Prompt.any_key("Press RETURN to continue...")')
        write("\r")
        assert_output_includes("Press RETURN to continue...\n#{"\r".inspect}")
      end

      def test_read_char_returns_the_read_char
        run_in_process('p CLI::UI::Prompt.read_char')
        write('c')
        assert_output_includes('c'.inspect)
      end

      def test_read_char_returns_only_the_next_read_char
        run_in_process('p CLI::UI::Prompt.read_char')
        write('char')
        assert_output_includes('c'.inspect)
      end

      private

      def run_in_process(code)
        @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(
          'ruby',
          '-r',
          'bundler/setup',
          '-r',
          'cli/ui',
          '-e',
          "$stdout.sync = true; $stderr.sync = true; #{code}",
        )
      end

      def wait_for_output_to_include(text)
        @output = ''
        until @output.include?(text)
          begin
            @output += @stdout.read_nonblock(100)
          rescue IO::WaitReadable
            IO.select([@stdout])
            retry
          end
        end
      end

      def write(text)
        @stdin.write(text)
      end

      def kill_process
        Process.kill('INT', @wait_thr[:pid])
      end

      def clean_up
        @wait_thr.value
        yield if block_given?
      ensure
        @stdin.close
        @stderr.close
        @stdout.close
      end

      def assert_output_includes(text)
        clean_up do
          assert_includes(@stdout.read, text)
        end
      end

      def assert_error_includes(text)
        clean_up do
          assert_includes(@stderr.read, text)
        end
      end

      def jruby_skip(message)
        skip(message) if RUBY_ENGINE.include?('jruby')
      end
    end
  end
end
