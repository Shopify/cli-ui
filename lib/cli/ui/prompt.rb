require 'cli/ui'
require 'readline'

module CLI
  module UI
    module Prompt
      autoload :InteractiveOptions,  'cli/ui/prompt/interactive_options'
      autoload :OptionsHandler,      'cli/ui/prompt/options_handler'
      private_constant :InteractiveOptions, :OptionsHandler

      class << self
        # Ask a user a question with either free form answer or a set of answers
        # Do not use this method for multiple choice questions. Use +ask_interactive+
        # Do not use this method for yes/no questions. Use +confirm+
        #
        # * Handles free form answers (options are nil)
        # * Handles default answers for free form text
        # * Handles file auto completion for file input
        #
        # https://user-images.githubusercontent.com/3074765/33799822-47f23302-dd01-11e7-82f3-9072a5a5f611.png
        #
        # ==== Attributes
        #
        # * +question+ - (required) The question to ask the user
        #
        # ==== Options
        #
        # * +:options+ - Options that the user can select from. (DEPRECATED: use +ask_interactive+)
        # * +:default+ - The default answer to the question (e.g. they just press enter and don't input anything)
        # * +:is_file+ - Tells the input to use file auto-completion (tab completion)
        # * +:allow_empty+ - Allows the answer to be empty
        #
        # Note:
        # * +:options+ conflicts with +:default+ and +:is_file+, you cannot set options with either of these keywords
        # * +:default+ conflicts with +:allow_empty:, you cannot set these together
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
        def ask(question, options: nil, default: nil, is_file: nil, allow_empty: true)
          if (default && !allow_empty) || (options && (default || is_file))
            raise(ArgumentError, 'conflicting arguments')
          end

          # For backwards compatibility
          return ask_interactive(question, options) if options

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

        # Asks the user an interactive (multiple choice) question
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control
        #
        # * Handles interactively choosing answers using +InteractiveOptions+
        #
        # ==== Options
        #
        # * +:options+ - Options that the user can select from.
        #
        # ==== Block (optional)
        #
        # * A Proc that takes a +OptionsHandler+ and uses the public +:add_option+ method to add options and their
        #   respective handlers
        #
        # Note:
        # * +:options+ conflicts with passing in the +Block+
        # * One of +:options+ or the +Block+ must be passed
        #
        # ==== Example Usage:
        #
        # Interactive (multiple choice) question
        #   CLI::UI::Prompt.ask_interactive('What kind of project is this?', options: %w(rails go ruby python))
        #
        # Interactive (multiple choice) question with defined handlers
        #   CLI::UI::Prompt.ask_interactive('What kind of project is this?', options: %w(rails go ruby python)) do |handler|
        #     handler.add_option('rails')  { |selection| puts selection } => outputs "rails" if selected
        #     handler.add_option('go')     { |selection| puts selection } => outputs "go" if selected
        #     handler.add_option('ruby')   { |selection| puts selection } => outputs "ruby" if selected
        #     handler.add_option('python') { |selection| puts selection } => outputs "python" if selected
        #
        def ask_interactive(question, options = nil)
          raise(ArgumentError, 'conflicting arguments') if options && block_given?

          options ||= if block_given?
            handler = OptionsHandler.new
            yield handler
            handler.options
          end

          raise(ArgumentError, 'insufficient options') if options.nil? || options.size < 2
          puts_question("#{question} {{yellow:(choose with ↑ ↓ ⏎)}}")
          resp = InteractiveOptions.call(options)

          # Clear the line, and reset the question to include the answer
          print(ANSI.previous_line + ANSI.end_of_line + ' ')
          print(ANSI.cursor_save)
          print(' ' * CLI::UI::Terminal.width)
          print(ANSI.cursor_restore)
          puts_question("#{question} (You chose: {{italic:#{resp}}})")

          return handler.call(resp) if block_given?
          resp
        end

        # Asks the user a yes/no question.
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control
        #
        # ==== Example Usage:
        #
        # Confirmation question
        #   CLI::UI::Prompt.confirm('Is the sky blue?')
        #
        def confirm(question)
          ask_interactive(question, %w(yes no)) == 'yes'
        end

        private

        def write_default_over_empty_input(default)
          CLI::UI.raw do
            STDERR.puts(
              CLI::UI::ANSI.cursor_up(1) +
              "\r" +
              CLI::UI::ANSI.cursor_forward(4) + # TODO: width
              default +
              CLI::UI::Color::RESET.code
            )
          end
        end

        def puts_question(str)
          CLI::UI.with_frame_color(:blue) do
            STDOUT.puts(CLI::UI.fmt('{{?}} ' + str))
          end
        end

        def readline(is_file: false)
          if is_file
            Readline.completion_proc = Readline::FILENAME_COMPLETION_PROC
            Readline.completion_append_character = ""
          else
            Readline.completion_proc = proc { |*| nil }
            Readline.completion_append_character = " "
          end

          # because Readline is a C library, CLI::UI's hooks into $stdout don't
          # work. We could work around this by having CLI::UI use a pipe and a
          # thread to manage output, but the current strategy feels like a
          # better tradeoff.
          prefix = CLI::UI.with_frame_color(:blue) { CLI::UI::Frame.prefix }
          prompt = prefix + CLI::UI.fmt('{{blue:> }}{{yellow:')

          begin
            line = Readline.readline(prompt, true)
            line.to_s.chomp
          rescue Interrupt
            CLI::UI.raw { STDERR.puts('^C' + CLI::UI::Color::RESET.code) }
            raise
          end
        end
      end
    end
  end
end
