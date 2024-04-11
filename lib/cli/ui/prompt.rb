# coding: utf-8

# typed: true

require 'cli/ui'
begin
  require 'reline' # For 2.7+
rescue LoadError
  require 'readline' # For 2.6
  Object.const_set(:Reline, Readline)
end

module CLI
  module UI
    module Prompt
      autoload :InteractiveOptions,  'cli/ui/prompt/interactive_options'
      autoload :OptionsHandler,      'cli/ui/prompt/options_handler'

      class << self
        extend T::Sig

        sig { returns(Color) }
        def instructions_color
          @instructions_color ||= Color::YELLOW
        end

        # Set the instructions color.
        #
        # ==== Attributes
        #
        # * +color+ - the color to use for prompt instructions
        #
        sig { params(color: Colorable).void }
        def instructions_color=(color)
          @instructions_color = CLI::UI.resolve_color(color)
        end

        # Ask a user a question with either free form answer or a set of answers (multiple choice)
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control multiple choice selection
        # Do not use this method for yes/no questions. Use +confirm+
        #
        # * Handles free form answers (options are nil)
        # * Handles default answers for free form text
        # * Handles file auto completion for file input
        # * Handles interactively choosing answers using +InteractiveOptions+
        #
        # https://user-images.githubusercontent.com/3074765/33799822-47f23302-dd01-11e7-82f3-9072a5a5f611.png
        #
        # ==== Attributes
        #
        # * +question+ - (required) The question to ask the user
        #
        # ==== Options
        #
        # * +:options+ - Options that the user may select from. Will use +InteractiveOptions+ to do so.
        # * +:default+ - The default answer to the question (e.g. they just press enter and don't input anything)
        # * +:is_file+ - Tells the input to use file auto-completion (tab completion)
        # * +:allow_empty+ - Allows the answer to be empty
        # * +:multiple+ - Allow multiple options to be selected
        # * +:filter_ui+ - Enable option filtering (default: true)
        # * +:select_ui+ - Enable long-form option selection (default: true)
        #
        # Note:
        # * +:options+ or providing a +Block+ conflicts with +:default+ and +:is_file+,
        #              you cannot set options with either of these keywords
        # * +:default+ conflicts with +:allow_empty:, you cannot set these together
        # * +:options+ conflicts with providing a +Block+ , you may only set one
        # * +:multiple+ can only be used with +:options+ or a +Block+; it is ignored, otherwise.
        #
        # ==== Block (optional)
        #
        # * A Proc that provides a +OptionsHandler+ and uses the public +:option+ method to add options and their
        #   respective handlers
        #
        # ==== Return Value
        #
        # * If a +Block+ was not provided, the selected option or response to the free form question will be returned
        # * If a +Block+ was provided, the evaluated value of the +Block+ will be returned
        #
        # ==== Example Usage:
        #
        # Free form question
        #   CLI::UI::Prompt.ask('What color is the sky?')
        #
        # Free form question with a file answer
        #   CLI::UI::Prompt.ask('Where is your Gemfile located?', is_file: true)
        #
        # Free form question with a default answer
        #   CLI::UI::Prompt.ask('What color is the sky?', default: 'blue')
        #
        # Free form question when the answer can be empty
        #   CLI::UI::Prompt.ask('What is your opinion on this question?', allow_empty: true)
        #
        # Interactive (multiple choice) question
        #   CLI::UI::Prompt.ask('What kind of project is this?', options: %w(rails go ruby python))
        #
        # Interactive (multiple choice) question with defined handlers
        #   CLI::UI::Prompt.ask('What kind of project is this?') do |handler|
        #     handler.option('rails')  { |selection| selection }
        #     handler.option('go')     { |selection| selection }
        #     handler.option('ruby')   { |selection| selection }
        #     handler.option('python') { |selection| selection }
        #   end
        #
        sig do
          params(
            question: String,
            options: T.nilable(T::Array[String]),
            default: T.nilable(T.any(String, T::Array[String])),
            is_file: T::Boolean,
            allow_empty: T::Boolean,
            multiple: T::Boolean,
            filter_ui: T::Boolean,
            select_ui: T::Boolean,
            options_proc: T.nilable(T.proc.params(handler: OptionsHandler).void),
          ).returns(T.any(String, T::Array[String]))
        end
        def ask(
          question,
          options: nil,
          default: nil,
          is_file: false,
          allow_empty: true,
          multiple: false,
          filter_ui: true,
          select_ui: true,
          &options_proc
        )
          has_options = !!(options || block_given?)
          if has_options && default && !multiple
            raise(ArgumentError, 'conflicting arguments: default may not be provided with options when not multiple')
          end

          if has_options && is_file
            raise(ArgumentError, 'conflicting arguments: is_file is only useful when options are not provided')
          end

          if options && multiple && default && !(Array(default) - options).empty?
            raise(ArgumentError, 'conflicting arguments: default should only include elements present in options')
          end

          if multiple && !has_options
            raise(ArgumentError, 'conflicting arguments: options must be provided when multiple is true')
          end

          if !multiple && default.is_a?(Array)
            raise(ArgumentError, 'conflicting arguments: multiple defaults may only be provided when multiple is true')
          end

          if has_options
            ask_interactive(
              question,
              options,
              multiple: multiple,
              default: default,
              filter_ui: filter_ui,
              select_ui: select_ui,
              &options_proc
            )
          else
            ask_free_form(question, T.cast(default, T.nilable(String)), is_file, allow_empty)
          end
        end

        # Asks the user for a single-line answer, without displaying the characters while typing.
        # Typically used for password prompts
        #
        # ==== Return Value
        #
        # The password, without a trailing newline.
        # If the user simply presses "Enter" without typing any password, this will return an empty string.
        sig { params(question: String).returns(String) }
        def ask_password(question)
          require 'io/console'

          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            $stdout.print(CLI::UI.fmt('{{?}} ' + question)) # Do not use puts_question to avoid the new line.

            # noecho interacts poorly with Readline under system Ruby, so do a manual `gets` here.
            # No fancy Readline integration (like echoing back) is required for a password prompt anyway.
            password = $stdin.noecho do
              # Chomp will remove the one new line character added by `gets`, without touching potential extra spaces:
              # " 123 \n".chomp => " 123 "
              $stdin.gets.to_s.chomp
            end

            $stdout.puts # Complete the line

            password
          end
        end

        # Asks the user a yes/no question.
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control
        #
        # ==== Example Usage:
        #
        # Confirmation question
        #   CLI::UI::Prompt.confirm('Is the sky blue?')
        #
        #   CLI::UI::Prompt.confirm('Do a dangerous thing?', default: false)
        #
        sig { params(question: String, default: T::Boolean).returns(T::Boolean) }
        def confirm(question, default: true)
          ask_interactive(question, default ? ['yes', 'no'] : ['no', 'yes'], filter_ui: false) == 'yes'
        end

        # Present the user with a message and wait for any key to be pressed, returning the pressed key.
        #
        # ==== Example Usage:
        #
        #   CLI::UI::Prompt.any_key # Press any key to continue...
        #
        #   CLI::UI::Prompt.any_key('Press RETURN to continue...') # Then check if that's what they pressed
        sig { params(prompt: String).returns(T.nilable(String)) }
        def any_key(prompt = 'Press any key to continue...')
          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            puts_question(prompt)
            read_char
          end
        end

        # Wait for any key to be pressed, returning the pressed key.
        sig { returns(T.nilable(String)) }
        def read_char
          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            if $stdin.tty? && !ENV['TEST']
              require 'io/console'
              $stdin.getch # raw mode for tty
            else
              $stdin.getc # returns nil at end of input
            end
          end
        rescue Errno::EIO, Errno::EPIPE, IOError
          "\e"
        end

        private

        sig do
          params(question: String, default: T.nilable(String), is_file: T::Boolean, allow_empty: T::Boolean)
            .returns(String)
        end
        def ask_free_form(question, default, is_file, allow_empty)
          if default && !allow_empty
            raise(ArgumentError, 'conflicting arguments: default enabled but allow_empty is false')
          end

          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            if default
              puts_question("#{question} (empty = #{default})")
            else
              puts_question(question)
            end

            # Ask a free form question
            loop do
              line = readline(is_file: is_file)

              if line.empty? && default
                write_default_over_empty_input(default)
                return default
              end

              if !line.empty? || allow_empty
                return line
              end
            end
          end
        end

        sig do
          params(
            question: String,
            options: T.nilable(T::Array[String]),
            multiple: T::Boolean,
            default: T.nilable(T.any(String, T::Array[String])),
            filter_ui: T::Boolean,
            select_ui: T::Boolean,
          ).returns(T.any(String, T::Array[String]))
        end
        def ask_interactive(question, options = nil, multiple: false, default: nil, filter_ui: true, select_ui: true)
          raise(ArgumentError, 'conflicting arguments: options and block given') if options && block_given?

          options ||= if block_given?
            handler = OptionsHandler.new
            yield handler
            handler.options
          end

          raise(ArgumentError, 'insufficient options') if options.nil? || options.empty?

          navigate_text = if CLI::UI::OS.current.suggest_arrow_keys?
            'Choose with ↑ ↓ ⏎'
          else
            "Navigate up with 'k' and down with 'j', press Enter to select"
          end

          instructions = (multiple ? 'Toggle options. ' : '') + navigate_text
          instructions += ", filter with 'f'" if filter_ui
          instructions += ", enter option with 'e'" if select_ui && (options.size > 9)

          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            puts_question("#{question} " + instructions_color.code + "(#{instructions})" + Color::RESET.code)
            resp = interactive_prompt(options, multiple: multiple, default: default)

            # Clear the line
            print(ANSI.previous_line + ANSI.clear_to_end_of_line)
            # Force StdoutRouter to prefix
            print(ANSI.previous_line + "\n")

            # reset the question to include the answer
            resp_text = case resp
            when Array
              case resp.size
              when 0
                '<nothing>'
              when 1..2
                resp.join(' and ')
              else
                "#{resp.size} items"
              end
            else
              resp
            end
            puts_question("#{question} (You chose: {{italic:#{resp_text}}})")

            if block_given?
              T.must(handler).call(resp)
            else
              resp
            end
          end
        end

        # Useful for stubbing in tests
        sig do
          params(options: T::Array[String], multiple: T::Boolean, default: T.nilable(T.any(T::Array[String], String)))
            .returns(T.any(T::Array[String], String))
        end
        def interactive_prompt(options, multiple: false, default: nil)
          CLI::UI::StdoutRouter::Capture.in_alternate_screen do
            InteractiveOptions.call(options, multiple: multiple, default: default)
          end
        end

        sig { params(default: String).void }
        def write_default_over_empty_input(default)
          CLI::UI.raw do
            $stderr.puts(
              CLI::UI::ANSI.cursor_up(1) +
              "\r" +
              CLI::UI::ANSI.cursor_forward(4) + # TODO: width
              default +
              CLI::UI::Color::RESET.code,
            )
          end
        end

        sig { params(str: String).void }
        def puts_question(str)
          $stdout.puts(CLI::UI.fmt('{{?}} ' + str))
        end

        sig { params(is_file: T::Boolean).returns(String) }
        def readline(is_file: false)
          if is_file
            Reline.completion_proc = proc do |input|
              directory = input[-1] == '/' ? input : File.dirname(input)
              filename = input[-1] == '/' ? '' : File.basename(input)

              (Dir.entries(directory).select do |fp|
                fp.start_with?(filename)
              end - (input[-1] == '.' ? [] : ['.', '..'])).map do |fp|
                File.join(directory, fp).gsub(/\A\.\//, '')
              end
            end
            Reline.completion_append_character = ''
          else
            Reline.completion_proc = proc { |*| nil }
            Reline.completion_append_character = ' '
          end

          # because Readline is a C library, CLI::UI's hooks into $stdout don't
          # work. We could work around this by having CLI::UI use a pipe and a
          # thread to manage output, but the current strategy feels like a
          # better tradeoff.
          prefix = CLI::UI::Frame.prefix
          # If a prompt is interrupted on Windows it locks the colour of the terminal from that point on, so we should
          # not change the colour here.
          prompt = prefix + CLI::UI.fmt('{{blue:> }}')
          prompt += CLI::UI::Color::YELLOW.code if CLI::UI::OS.current.use_color_prompt?

          begin
            line = Reline.readline(prompt, true)
            print(CLI::UI::Color::RESET.code)
            line.to_s.chomp
          rescue Interrupt
            CLI::UI.raw { $stderr.puts('^C' + CLI::UI::Color::RESET.code) }
            raise
          end
        end
      end
    end
  end
end
