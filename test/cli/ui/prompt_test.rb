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
          begin
            Prompt.confirm('q')
          rescue Interrupt
            @ret.write(Marshal.dump(:SIGINT))
          end
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
          begin
            Prompt.ask('q')
          rescue Interrupt
            @ret.write(Marshal.dump(:SIGINT))
          end
        end

        sleep(0.05)
        Process.kill('INT', @pid)

        assert_result("? q\n> ", "^C\n", :SIGINT)
      end

      def test_ask_interactive_sigint
        start_process do
          begin
            Prompt.ask('q', options: %w(a b))
          rescue Interrupt
            @ret.write(Marshal.dump(:SIGINT))
          end
        end

        sleep(0.05)
        Process.kill('INT', @pid)

        expected_out = strip_heredoc(<<-EOF) + ' '
          ? q (Choose with ↑ ↓ ⏎)
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
        assert_equal 'conflicting arguments: default enabled but allow_empty is false', error.message

        error = assert_raises(ArgumentError) do
          Prompt.ask('q', default: 'b') {}
        end
        assert_equal 'conflicting arguments: options provided with default or is_file', error.message
      end

      def test_ask_interactive_conflicting_arguments
        error = assert_raises(ArgumentError) do
          Prompt.ask('q', options: %w(a b)) { |h| h.option('a') }
        end
        assert_equal 'conflicting arguments: options and block given', error.message
      end

      def test_ask_interactive_insufficient_options
        exception = assert_raises(ArgumentError) do
          Prompt.ask('q', options: %w(a))
        end
        assert_equal 'insufficient options', exception.message

        exception = assert_raises(ArgumentError) do
          Prompt.ask('q') { |h| h.option('a') {} }
        end
        assert_equal 'insufficient options', exception.message
      end

      def test_ask_interactive_with_block
        _run('2') do
          Prompt.ask('q') do |h|
            h.option('a') { |a| 'a was selected' }
            h.option('b') { |b| 'b was selected' }
          end
        end
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎)
          \e[?25l> 1. a\e[K
            2. b\e[K
          #{' ' * CLI::UI::Terminal.width}
          #{' ' * CLI::UI::Terminal.width}
          \e[?25h\e[K
          ? q (You chose: b)
        EOF
        assert_result(expected_out, "", "b was selected")
      end

      def test_ask_interactive_with_number
        _run('2') do
          Prompt.ask('q', options: %w(a b))
        end
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎)
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
        ? q (Choose with ↑ ↓ ⏎)
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
        ? q (Choose with ↑ ↓ ⏎)
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
          begin
            Prompt.ask('q', options: %w(a b))
          rescue Interrupt
            @ret.write(Marshal.dump(:SIGINT))
          end
        end

        expected_out = strip_heredoc(<<-EOF)
        ? q (Choose with ↑ ↓ ⏎)
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
        ? q (Choose with ↑ ↓ ⏎)
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
        _run('j','j',' ') do
          Prompt.ask('q') do |h|
            h.option('a') { |a| 'a was selected' }
            h.option('') { |b| 'b was selected' }
          end
        end
        blank = ''
        expected_out = strip_heredoc(<<-EOF)
          ? q (Choose with ↑ ↓ ⏎)
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

        assert_equal(out.strip, actual_out.strip)
        assert_equal(err.strip, actual_err.strip) if err
        assert_equal(ret, actual_ret)
      end

      def strip_heredoc(str)
        str.gsub(/^#{str.scan(/^[ \t]*(?=\S)/).min}/, "".freeze)
      end
    end
  end
end
