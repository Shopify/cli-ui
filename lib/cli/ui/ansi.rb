# typed: true
# frozen_string_literal: true

require 'cli/ui'

module CLI
  module UI
    module ANSI
      ESC = "\x1b"
      # https://ghostty.org/docs/vt/concepts/sequences#csi-sequences
      CSI_SEQUENCE = /\x1b\[[\d;:]+[\x20-\x2f]*?[\x40-\x7e]/
      # https://ghostty.org/docs/vt/concepts/sequences#osc-sequences
      # OSC sequences can be terminated with either ST (\x1b\x5c) or BEL (\x07)
      OSC_SEQUENCE = /\x1b\][^\x07\x1b]*?(?:\x07|\x1b\x5c)/

      class << self
        # ANSI escape sequences (like \x1b[31m) have zero width.
        # when calculating the padding width, we must exclude them.
        # This also implements a basic version of utf8 character width calculation like
        # we could get for real from something like utf8proc.
        #
        #: (String str) -> Integer
        def printing_width(str)
          zwj = false #: bool
          strip_codes(str).codepoints.reduce(0) do |acc, cp|
            if zwj
              zwj = false
              next acc
            end
            case cp
            when 0x200d # zero-width joiner
              zwj = true
              acc
            when "\n"
              acc
            else
              acc + 1
            end
          end
        end

        # Strips ANSI codes from a str
        #
        # ==== Attributes
        #
        # - +str+ - The string from which to strip codes
        #
        #: (String str) -> String
        def strip_codes(str)
          str.gsub(Regexp.union(CSI_SEQUENCE, OSC_SEQUENCE, /\r/), '')
        end

        # Returns an ANSI control sequence
        #
        # ==== Attributes
        #
        # - +args+ - Argument to pass to the ANSI control sequence
        # - +cmd+ - ANSI control sequence Command
        #
        #: (String args, String cmd) -> String
        def control(args, cmd)
          ESC + '[' + args + cmd
        end

        # https://en.wikipedia.org/wiki/ANSI_escape_code#graphics
        #: (String params) -> String
        def sgr(params)
          control(params, 'm')
        end

        # Cursor Movement

        # Move the cursor up n lines
        #
        # ==== Attributes
        #
        # * +n+ - number of lines by which to move the cursor up
        #
        #: (?Integer n) -> String
        def cursor_up(n = 1)
          return '' if n.zero?

          control(n.to_s, 'A')
        end

        # Move the cursor down n lines
        #
        # ==== Attributes
        #
        # * +n+ - number of lines by which to move the cursor down
        #
        #: (?Integer n) -> String
        def cursor_down(n = 1)
          return '' if n.zero?

          control(n.to_s, 'B')
        end

        # Move the cursor forward n columns
        #
        # ==== Attributes
        #
        # * +n+ - number of columns by which to move the cursor forward
        #
        #: (?Integer n) -> String
        def cursor_forward(n = 1)
          return '' if n.zero?

          control(n.to_s, 'C')
        end

        # Move the cursor back n columns
        #
        # ==== Attributes
        #
        # * +n+ - number of columns by which to move the cursor back
        #
        #: (?Integer n) -> String
        def cursor_back(n = 1)
          return '' if n.zero?

          control(n.to_s, 'D')
        end

        # Move the cursor to a specific column
        #
        # ==== Attributes
        #
        # * +n+ - The column to move to
        #
        #: (?Integer n) -> String
        def cursor_horizontal_absolute(n = 1)
          cmd = control(n.to_s, 'G')
          cmd += cursor_back if CLI::UI::OS.current.shift_cursor_back_on_horizontal_absolute?
          cmd
        end

        #: -> String
        def enter_alternate_screen
          control('?1049', 'h')
        end

        #: -> String
        def exit_alternate_screen
          control('?1049', 'l')
        end

        #: -> Regexp
        def match_alternate_screen
          /#{Regexp.escape(control("?1049", ""))}[hl]/
        end

        # Show the cursor
        #
        #: -> String
        def show_cursor
          control('', '?25h')
        end

        # Hide the cursor
        #
        #: -> String
        def hide_cursor
          control('', '?25l')
        end

        # Save the cursor position
        #
        #: -> String
        def cursor_save
          control('', 's')
        end

        # Restore the saved cursor position
        #
        #: -> String
        def cursor_restore
          control('', 'u')
        end

        # Move to the next line
        #
        #: -> String
        def next_line
          cursor_down + cursor_horizontal_absolute
        end

        # Move to the previous line
        #
        #: -> String
        def previous_line
          previous_lines(1)
        end

        # Move to the previous n lines
        #
        # ==== Attributes
        #
        # * +n+ - number of lines by which to move the cursor up
        #
        #: (?Integer n) -> String
        def previous_lines(n = 1)
          cursor_up(n) + cursor_horizontal_absolute
        end

        #: -> String
        def clear_to_end_of_line
          control('', 'K')
        end

        #: -> String
        def insert_line
          insert_lines(1)
        end

        #: (?Integer n) -> String
        def insert_lines(n = 1)
          control(n.to_s, 'L')
        end
      end
    end
  end
end
