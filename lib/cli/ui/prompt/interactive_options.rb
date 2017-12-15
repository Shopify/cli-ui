require 'io/console'

module CLI
  module UI
    module Prompt
      class InteractiveOptions
        # Prompts the user with options
        # Uses an interactive session to allow the user to pick an answer
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control
        #
        # https://user-images.githubusercontent.com/3074765/33797984-0ebb5e64-dcdf-11e7-9e7e-7204f279cece.gif
        #
        # ==== Example Usage:
        #
        # Ask an interactive question
        #   CLI::UI::Prompt::InteractiveOptions.call(%w(rails go python))
        #
        def self.call(options)
          list = new(options)
          options[list.call - 1]
        end

        # Initializes a new +InteractiveOptions+
        # Usually called from +self.call+
        #
        # ==== Example Usage:
        #
        #   CLI::UI::Prompt::InteractiveOptions.new(%w(rails go python))
        #
        def initialize(options)
          @options = options
          @active = 1
          @marker = '>'
          @answer = nil
          @state = :root
        end

        # Calls the +InteractiveOptions+ and asks the question
        # Usually used from +self.call+
        #
        def call
          CLI::UI.raw { print(ANSI.hide_cursor) }
          while @answer.nil?
            render_options
            wait_for_user_input
            reset_position
          end
          clear_output
          @answer
        ensure
          CLI::UI.raw do
            print(ANSI.show_cursor)
            puts(ANSI.previous_line + ANSI.end_of_line)
          end
        end

        private

        def reset_position
          # This will put us back at the beginning of the options
          # When we redraw the options, they will be overwritten
          CLI::UI.raw do
            num_lines.times { print(ANSI.previous_line) }
            print(ANSI.previous_line + ANSI.end_of_line + "\n")
          end
        end

        def clear_output
          CLI::UI.raw do
            # Write over all lines with whitespace
            num_lines.times { puts(' ' * CLI::UI::Terminal.width) }
          end
          reset_position
        end

        def num_lines
          # @options will be an array of questions but each option can be multi-line
          # so to get the # of lines, you need to join then split
          joined_options = @options.join("\n")
          joined_options.split("\n").reject(&:empty?).size
        end

        ESC = "\e"

        def up
          @active = @active - 1 >= 1 ? @active - 1 : @options.length
        end

        def down
          @active = @active + 1 <= @options.length ? @active + 1 : 1
        end

        def select_n(n)
          @active = n
          @answer = n
        end

        def select_bool(char)
          return unless (@options - %w(yes no)).empty?
          opt = @options.detect { |o| o.start_with?(char) }
          @active = @options.index(opt) + 1
          @answer = @options.index(opt) + 1
        end

        # rubocop:disable Style/WhenThen,Layout/SpaceBeforeSemicolon
        def wait_for_user_input
          char = read_char
          case @state
          when :root
            case char
            when ESC                       ; @state = :esc
            when 'k'                       ; up
            when 'j'                       ; down
            when ('1'..@options.size.to_s) ; select_n(char.to_i)
            when 'y', 'n'                  ; select_bool(char)
            when " ", "\r", "\n"           ; @answer = @active # <enter>
            when "\u0003"                  ; raise Interrupt   # Ctrl-c
            end
          when :esc
            case char
            when '[' ; @state = :esc_bracket
            else     ; raise Interrupt # unhandled escape sequence.
            end
          when :esc_bracket
            @state = :root
            case char
            when 'A' ; up
            when 'B' ; down
            else     ; raise Interrupt # unhandled escape sequence.
            end
          end
        end
        # rubocop:enable Style/WhenThen,Layout/SpaceBeforeSemicolon

        def read_char
          raw_tty! { $stdin.getc.chr }
        rescue IOError
          "\e"
        end

        def raw_tty!
          if ENV['TEST'] || !$stdin.tty?
            yield
          else
            $stdin.raw { yield }
          end
        end

        def render_options
          max_num_length = (@options.size + 1).to_s.length
          @options.each_with_index do |choice, index|
            num = index + 1
            padding = ' ' * (max_num_length - num.to_s.length)
            message = "  #{num}.#{padding}"
            message += choice.split("\n").map { |l| " {{bold:#{l}}}" }.join("\n")

            if num == @active
              message = message.split("\n").map.with_index do |l, idx|
                idx == 0 ? "{{blue:> #{l.strip}}}" : "{{blue:>#{l.strip}}}"
              end.join("\n")
            end

            CLI::UI.with_frame_color(:blue) do
              puts CLI::UI.fmt(message)
            end
          end
        end
      end
    end
  end
end
