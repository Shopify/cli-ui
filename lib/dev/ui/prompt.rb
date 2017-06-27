require 'dev/ui'
require 'readline'

module Dev
  module UI
    module Prompt
      class << self
        def ask(question, options: nil, default: nil, is_file: nil, allow_empty: true)
          if (default && !allow_empty) || (options && (default || is_file))
            raise(ArgumentError, 'conflicting arguments')
          end

          if default
            puts_question("#{question} (empty = #{default})")
          elsif options
            puts_question("#{question} {{yellow:(choose with ↑ ↓ ⏎)}}")
          else
            puts_question(question)
          end

          return InteractivePrompt.call(options) if options

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

        def confirm(question)
          puts_question("#{question} {{yellow:(choose with ↑ ↓ ⏎)}}")
          InteractivePrompt.call(%w(yes no)) == 'yes'
        end

        private

        def write_default_over_empty_input(default)
          Dev::UI.raw do
            STDERR.puts(
              Dev::UI::ANSI.cursor_up(1) +
              "\r" +
              Dev::UI::ANSI.cursor_forward(4) + # TODO: width
              default +
              Dev::UI::Color::RESET.code
            )
          end
        end

        def puts_question(str)
          Dev::UI.with_frame_color(:blue) do
            STDOUT.puts(Dev::UI.fmt('{{?}} ' + str))
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

          # because Readline is a C library, Dev::UI's hooks into $stdout don't
          # work. We could work around this by having Dev::UI use a pipe and a
          # thread to manage output, but the current strategy feels like a
          # better tradeoff.
          prefix = Dev::UI.with_frame_color(:blue) { Dev::UI::Frame.prefix }
          prompt = prefix + Dev::UI.fmt('{{blue:> }}{{yellow:')

          begin
            line = Readline.readline(prompt, true)
            line && line.chomp
          rescue Interrupt
            Dev::UI.raw { STDERR.puts('^C' + Dev::UI::Color::RESET.code) }
            raise
          end
        end
      end
    end
  end
end
