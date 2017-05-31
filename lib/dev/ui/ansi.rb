require 'dev/ui'

module Dev
  module UI
    module ANSI
      ESC = "\x1b"

      # ANSI escape sequences (like \x1b[31m) have zero width.
      # when calculating the padding width, we must exclude them.
      def self.printing_width(str)
        strip_codes(str).size
      end

      def self.strip_codes(str)
        str.gsub(/\x1b\[[\d;]+[A-z]|\r/, '')
      end

      def self.control(args, cmd)
        ESC + "[" + args + cmd
      end

      # https://en.wikipedia.org/wiki/ANSI_escape_code#graphics
      def self.sgr(params)
        control(params.to_s, 'm')
      end

      # Cursor Movement

      def self.cursor_up(n = 1)
        return '' if n.zero?
        control(n.to_s, 'A')
      end

      def self.cursor_down(n = 1)
        return '' if n.zero?
        control(n.to_s, 'B')
      end

      def self.cursor_forward(n = 1)
        return '' if n.zero?
        control(n.to_s, 'C')
      end

      def self.cursor_back(n = 1)
        return '' if n.zero?
        control(n.to_s, 'D')
      end

      # Cursor Visibility

      def self.show_cursor
        control('', "?25h")
      end

      def self.hide_cursor
        control('', "?25l")
      end

      # Line Handling

      def self.next_line
        cursor_down + control('1', 'G')
      end

      def self.previous_line
        cursor_up + control('1', 'G')
      end

      def self.end_of_line
        control("\033[", 'C')
      end
    end
  end
end
