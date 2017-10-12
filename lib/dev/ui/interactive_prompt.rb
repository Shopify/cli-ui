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

      def wait_for_user_input
        char = read_char
        char = char.chomp unless char.chomp.empty?
        case char
        when "\e[A", 'k'    # up
          @active = @active - 1 >= 1 ? @active - 1 : @options.length
        when "\e[B", 'j'    # down
          @active = @active + 1 <= @options.length ? @active + 1 : 1
        when " ", "\r"      # enter/select
          @answer = @active
        when ('1'..@options.size.to_s)
          @active = char.to_i
          @answer = char.to_i
        when 'y', 'n'
          return unless (@options - %w(yes no)).empty?
          opt = @options.detect { |o| o.start_with?(char) }
          @active = @options.index(opt) + 1
          @answer = @options.index(opt) + 1
        when "\u0003", "\e" # Control-C or escape
          raise Interrupt
        end
      end

      # Will handle 2-3 character sequences like arrow keys and control-c
      def read_char
        raw_tty! do
          input = $stdin.getc.chr
          return input unless input == "\e"

          input << begin
              $stdin.read_nonblock(3)
            rescue
              ''
            end
          input << begin
              $stdin.read_nonblock(2)
            rescue
              ''
            end
          input
        end
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
