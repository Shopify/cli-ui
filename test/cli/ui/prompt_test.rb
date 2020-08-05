# coding: utf-8
require 'test_helper'
require 'readline'
require 'timeout'

module CLI
  module UI
    class PromptTest < MiniTest::Test
      def setup
        @dir = Dir.mktmpdir
        @in_r, @in_w = IO.pipe
        @out_file = "#{@dir}/out"
        @err_file = "#{@dir}/err"
        @ret_file = "#{@dir}/ret"
        FileUtils.touch(@out_file)
        FileUtils.touch(@err_file)
        FileUtils.touch(@ret_file)
        super
      end

      def teardown
        FileUtils.rm_rf(@dir)
        super
      end

      # ^C is not handled; raises Interrupt, which may be handled by caller.
      def test_confirm_sigint
        start_process do
          Prompt.confirm('q')
        rescue Interrupt
          @ret.write(Marshal.dump(:SIGINT))
        end

        sleep(0.05)
        Process.kill('INT', @pid)

        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. yes\e[K
            2. no\e[K
          \e[?25h
        EOF
        assert_result(expected_out, "", :SIGINT)
      end

      # ^C is not handled; raises Interrupt, which may be handled by caller.
      def test_ask_free_form_sigint
        start_process do
          Prompt.ask('q')
        rescue Interrupt
          @ret.write(Marshal.dump(:SIGINT))
        end

        sleep(0.05)
        Process.kill('INT', @pid)

        assert_result("? q\n> ", "^C\n", :SIGINT)
      end

      def test_ask_interactive_sigint
        start_process do
          Prompt.ask('q', options: %w(a b))
        rescue Interrupt
          @ret.write(Marshal.dump(:SIGINT))
        end

        sleep(0.05)
        Process.kill('INT', @pid)

        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎, filter with 'f')
          \e[?25l> 1. a\e[K
            2. b\e[K
          \e[?25h
        EOF
        assert_result(expected_out, "", :SIGINT)
      end

      def test_confirm_happy_path
        _run('y') { assert Prompt.confirm('q') }
        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. yes\e[K
            2. no\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: yes)
        EOF
        assert_result(expected_out, "", true)
      end

      def test_confirm_default_no
        _run("\n") { Prompt.confirm('q', default: false) }

        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. no\e[K
            2. yes\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: no)
        EOF

        assert_result(expected_out, "", false)
      end

      def test_confirm_invalid
        _run(%w(r y n)) { Prompt.confirm('q') }
        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. yes\e[K
            2. no\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: yes)
        EOF
        assert_result(expected_out, "", true)
      end

      def test_confirm_no_match_internal
        _run('x', 'n') { Prompt.confirm('q') }
        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. yes\e[K
            2. no\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: no)
        EOF
        assert_result(expected_out, "", false)
      end

      def test_confirm_no_arrow_keys
        # Windows doesn't detect presses on the arrow keys when picking an option, so we don't show the instruction text
        # for them.
        with_os_mock_and_reload(CLI::UI::OS::Windows) do
          _run('x', 'n') { Prompt.confirm('q') }
          expected_out = strip_heredoc(<<-EOF) + ' '
            ? q (Navigate up with 'k' and down with 'j', press Enter to select)
            \e[?25l> 1. yes\e[K
              2. no\e[K
            #{' ' * CLI::UI::Terminal.width}
            #{' ' * CLI::UI::Terminal.width}
            \e[?25h\e[K
            ? q (You chose: no)
          EOF
          assert_result(expected_out, "", false)
        end
      end

      def test_ask_free_form_happy_path
        _run('asdf') { Prompt.ask('q') }
        assert_result("? q\n> asdf\n", "", "asdf")
      end

      def test_ask_free_form_empty_answer_rejected
        _run("\n") { Prompt.ask('q') } # allow_empty: true
        assert_result("? q\n> \n", "", "")
      end

      def test_ask_free_form_empty_answer_allowed
        _run("\n", 'asdf') { Prompt.ask('q', allow_empty: false) }
        assert_result("? q\n> \n> asdf\n", "", "asdf")
      end

      def test_ask_free_form_no_filename_completion
        _run("/dev/nul\t") { Prompt.ask('q') }
        # \a = terminal bell, because completion failed
        assert_result("? q\n> /dev/nul\n", "\a", "/dev/nul")
      end

      def test_ask_free_form_filename_completion
        _run("/dev\tnul\t") { Prompt.ask('q', is_file: true) }
        # \a = terminal bell, because completion failed
        assert_result("? q\n> /dev/null\n", "", "/dev/null")
      end

      def test_ask_free_form_default
        _run('') { Prompt.ask('q', default: 'asdf') }
        # write to stderr is to overwrite default over empty prompt
        assert_result("? q (empty = asdf)\n> \n", "asdf\n", "asdf")
      end

      def test_ask_free_form_default_nondefault
        _run('zxcv') { Prompt.ask('q', default: 'asdf') }
        assert_result("? q (empty = asdf)\n> zxcv\n", "", "zxcv")
      end

      def test_ask_invalid_kwargs
        kwargsets = [
          { options: ['a'], default: 'a' },
          { options: ['a'], is_file: true },
        ]

        kwargsets.each do |kwargs|
          error = assert_raises(ArgumentError) { Prompt.ask('q', **kwargs) }
          assert_equal 'conflicting arguments: options provided with default or is_file', error.message
        end

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', default: 'a', allow_empty: false)
        end
        assert_equal('conflicting arguments: default enabled but allow_empty is false', error.message)

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', default: 'b') {}
        end
        assert_equal('conflicting arguments: options provided with default or is_file', error.message)
      end

      def test_ask_interactive_conflicting_arguments
        error = assert_raises(ArgumentError) do
          Prompt.ask('q', options: %w(a b)) { |h| h.option('a') }
        end
        assert_equal('conflicting arguments: options and block given', error.message)

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', options: %w(a b), multiple: true, default: %w(b c)) { |h| h.option('a') }
        end
        assert_equal('conflicting arguments: default should only include elements present in options', error.message)
      end

      def test_ask_interactive_insufficient_options
        exception = assert_raises(ArgumentError) do
          Prompt.ask('q', options: %w())
        end
        assert_equal('insufficient options', exception.message)

        exception = assert_raises(ArgumentError) do
          Prompt.ask('q') { |_h| {} }
        end
        assert_equal('insufficient options', exception.message)
      end

      def test_ask_interactive_with_block
        _run('1') do
          Prompt.ask('q') do |h|
            h.option('a') { |_a| 'a was selected' }
          end
        end
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎, filter with 'f')
          \e[?25l> 1. a\e[K
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: a)
        EOF
        assert_result(expected_out, "", "a was selected")
      end

      def test_ask_interactive_with_number
        _run('2') do
          Prompt.ask('q', options: %w(a b))
        end
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎, filter with 'f')
          \e[?25l> 1. a\e[K
            2. b\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: b)
        EOF
        assert_result(expected_out, "", "b")
      end

      def test_ask_interactive_with_vim_bound_arrows
        _run('j', ' ') do
          Prompt.ask('q', options: %w(a b))
        end
        expected_out = strip_heredoc(<<-EOF)
        ? q (Choose with ↑ ↓ ⏎, filter with 'f')
        \e[?25l> 1. a\e[K
          2. b\e[K
          1. a\e[K
        > 2. b\e[K
        #{' ' * CLI::UI::Terminal.width}
        #{' ' * CLI::UI::Terminal.width}
        \e[?25h\e[K
        ? q (You chose: b)
        EOF
        assert_result(expected_out, "", "b")
      end

      def test_ask_interactive_select_using_space
        _run(' ') do
          Prompt.ask('q', options: %w(a b))
        end
        expected_out = strip_heredoc(<<-EOF)
        ? q (Choose with ↑ ↓ ⏎, filter with 'f')
        \e[?25l> 1. a\e[K
          2. b\e[K
        #{' ' * CLI::UI::Terminal.width}
        #{' ' * CLI::UI::Terminal.width}
        \e[?25h\e[K
        ? q (You chose: a)
        EOF
        assert_result(expected_out, "", "a")
      end

      def test_ask_interactive_escape
        _run("\e") do
          Prompt.ask('q', options: %w(a b))
        rescue Interrupt
          @ret.write(Marshal.dump(:SIGINT))
        end

        expected_out = strip_heredoc(<<-EOF)
        ? q (Choose with ↑ ↓ ⏎, filter with 'f')
        \e[?25l> 1. a\e[K
          2. b\e[K
        \e[?25h
        EOF
        assert_result(expected_out, nil, :SIGINT)
      end

      def test_ask_interactive_invalid_input
        _run('3', 'nan', '2') do
          Prompt.ask('q', options: %w(a b))
        end
        expected_out = strip_heredoc(<<-EOF)
        ? q (Choose with ↑ ↓ ⏎, filter with 'f')
        \e[?25l> 1. a\e[K
          2. b\e[K
        #{' ' * CLI::UI::Terminal.width}
        #{' ' * CLI::UI::Terminal.width}
        \e[?25h\e[K
        ? q (You chose: b)
        EOF
        assert_result(expected_out, "", "b")
      end

      def test_ask_interactive_with_blank_option
        _run('j', 'j', ' ') do
          Prompt.ask('q') do |h|
            h.option('a') { |_a| 'a was selected' }
            h.option('') { |_b| 'b was selected' }
          end
        end
        blank = ''
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎, filter with 'f')
          \e[?25l> 1. a\e[K
            2.#{blank}\e[K
            1. a\e[K
          > 2.#{blank}\e[K
          > 1. a\e[K
            2.#{blank}\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: a)
        EOF
        assert_result(expected_out, "", "a was selected")
      end

      def test_ask_interactive_filter_options
        _run('f', 'a', "\n") do
          Prompt.ask('q', options: %w(a b))
        end

        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎, filter with 'f')
          \e[?25l> 1. a\e[K
            2. b\e[K
            Filter: Ctrl-D anytime or Backspace now to exit\e[K
          > 1. a\e[K
            2. b\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
            Filter: a\e[K
          > 1. a\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: a)
        EOF

        assert_result(expected_out, '', 'a')
      end

      def test_ask_interactive_line_selection
        _run('e', '1', '0', "\n") do
          Prompt.ask('q', options: ('1'..'10').to_a)
        end

        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎, filter with 'f', enter option with 'e')
          \e[?25l> 1.  1\e[K
            2.  2\e[K
            3.  3\e[K
            4.  4\e[K
            5.  5\e[K
            6.  6\e[K
            7.  7\e[K
            8.  8\e[K
            9.  9\e[K
            10. 10\e[K
            Select: e, q, or up/down anytime to exit\e[K
            1.  1\e[K
            2.  2\e[K
            3.  3\e[K
            4.  4\e[K
            5.  5\e[K
            6.  6\e[K
            7.  7\e[K
            8.  8\e[K
            9.  9\e[K
            10. 10\e[K
            Select: 1\e[K
          > 1.  1\e[K
            2.  2\e[K
            3.  3\e[K
            4.  4\e[K
            5.  5\e[K
            6.  6\e[K
            7.  7\e[K
            8.  8\e[K
            9.  9\e[K
            10. 10\e[K
            Select: 10\e[K
            1.  1\e[K
            2.  2\e[K
            3.  3\e[K
            4.  4\e[K
            5.  5\e[K
            6.  6\e[K
            7.  7\e[K
            8.  8\e[K
            9.  9\e[K
          > 10. 10\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: 10)
        EOF

        assert_result(expected_out, '', '10')
      end

      def test_ask_multiple
        _run('1', '3', '5', '0') do
          Prompt.ask('q', options: ('1'..'10').to_a, multiple: true)
        end

        assert_result(nil, nil, ['1', '3', '5'])
      end

      def test_ask_multiple_with_handler
        _run('1', '3', '5', '0') do
          Prompt.ask('q', multiple: true) do |handler|
            ('1'..'10').each do |i|
              handler.option(i) { i }
            end
          end
        end

        assert_result(nil, nil, ['1', '3', '5'])
      end

      def test_ask_multiple_with_default_values
        _run('1', '0') do
          Prompt.ask('q', options: ('1'..'10').to_a, multiple: true, default: %w(2 3))
        end

        assert_result(nil, nil, ['1', '2', '3'])
      end

      private

      def _run(*lines)
        $stdin = @in_r
        start_process { @ret.write(Marshal.dump(yield)) }
        @in_w.puts(lines.join(''))
      end

      def start_process
        @pid = fork do
          @ret = File.open(@ret_file, 'w')
          @ret.sync = true
          @in_w.close
          Readline.input = @in_r

          $stderr.reopen(File.open(@err_file, 'w'))
          $stdout.reopen(File.open(@out_file, 'w'))
          $stdout.sync = true
          $stderr.sync = true
          yield
          @ret.close
        end
        @in_r.close
      end

      def assert_result(out, err, ret)
        Timeout.timeout(0.25) { Process.wait(@pid) }

        actual_out = CLI::UI::ANSI.strip_codes(File.read(@out_file))
        actual_err = CLI::UI::ANSI.strip_codes(File.read(@err_file))
        actual_ret = Marshal.load(File.read(@ret_file))

        assert_equal(out.strip, actual_out.strip) if out
        assert_equal(err.strip, actual_err.strip) if err
        assert_equal(ret, actual_ret)
      end

      def strip_heredoc(str)
        str.gsub(/^#{str.scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
      end
    end
  end
end
