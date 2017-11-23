require 'io/console'

module Dev
  module UI
    class InteractivePrompt
      def self.call(options)
        list = new(options)
        options[list.call - 1]
      end

      def initialize(options)
        @options = options
        @active = 1
        @marker = '>'
        @answer = nil
        @state = :root
      end

      def call
        Dev::UI.raw { print(ANSI.hide_cursor) }
        while @answer.nil?
          render_options
          wait_for_user_input

          # This will put us back at the beginning of the options
          # When we redraw the options, they will be overwritten
          Dev::UI.raw do
            num_lines = @options.join("\n").split("\n").reject(&:empty?).size
            num_lines.times { print(ANSI.previous_line) }
            print(ANSI.previous_line + ANSI.end_of_line + "\n")
          end
        end
        render_options
        @answer
      ensure
        Dev::UI.raw do
          print(ANSI.show_cursor)
          puts(ANSI.previous_line + ANSI.end_of_line)
        end
      end

      private

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
        @options.each_with_index do |choice, index|
          num = index + 1
          message = "  #{num}."
          message += choice.split("\n").map { |l| " {{bold:#{l}}}" }.join("\n")

          if num == @active
            message = message.split("\n").map.with_index do |l, idx|
              idx == 0 ? "{{blue:> #{l.strip}}}" : "{{blue:>#{l.strip}}}"
            end.join("\n")
          end

          Dev::UI.with_frame_color(:blue) do
            puts Dev::UI.fmt(message)
          end
        end
      end
    end
  end
end
