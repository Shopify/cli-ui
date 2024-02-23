# typed: true

require 'cli/ui'

module CLI
  module UI
    module ANSI
      extend T::Sig

      ESC = "\x1b"

      class << self
        extend T::Sig

        # ANSI escape sequences (like \x1b[31m) have zero width.
        # when calculating the padding width, we must exclude them.
        # This also implements a basic version of utf8 character width calculation like
        # we could get for real from something like utf8proc.
        #
        sig { params(str: String).returns(Integer) }
        def printing_width(str)
          zwj = T.let(false, T::Boolean)
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
        sig { params(str: String).returns(String) }
        def strip_codes(str)
          str.gsub(/\x1b\[[\d;]+[A-Za-z]|\r/, '')
        end

        # Returns an ANSI control sequence
        #
        # ==== Attributes
        #
        # - +args+ - Argument to pass to the ANSI control sequence
        # - +cmd+ - ANSI control sequence Command
        #
        sig { params(args: String, cmd: String).returns(String) }
        def control(args, cmd)
          ESC + '[' + args + cmd
        end

        # https://en.wikipedia.org/wiki/ANSI_escape_code#graphics
        sig { params(params: String).returns(String) }
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
        sig { params(n: Integer).returns(String) }
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
        sig { params(n: Integer).returns(String) }
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
        sig { params(n: Integer).returns(String) }
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
        sig { params(n: Integer).returns(String) }
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
        sig { params(n: Integer).returns(String) }
        def cursor_horizontal_absolute(n = 1)
          cmd = control(n.to_s, 'G')
          cmd += cursor_back if CLI::UI::OS.current.shift_cursor_back_on_horizontal_absolute?
          cmd
        end

        sig { returns(String) }
        def enter_alternate_screen
          control('?1049', 'h')
        end

        sig { returns(String) }
        def exit_alternate_screen
          control('?1049', 'l')
        end

        sig { returns(Regexp) }
        def match_alternate_screen
          /#{Regexp.escape(control("?1049", ""))}[hl]/
        end

        # Show the cursor
        #
        sig { returns(String) }
        def show_cursor
          control('', '?25h')
        end

        # Hide the cursor
        #
        sig { returns(String) }
        def hide_cursor
          control('', '?25l')
        end

        # Save the cursor position
        #
        sig { returns(String) }
        def cursor_save
          control('', 's')
        end

        # Restore the saved cursor position
        #
        sig { returns(String) }
        def cursor_restore
          control('', 'u')
        end

        # Move to the next line
        #
        sig { returns(String) }
        def next_line
          cursor_down + cursor_horizontal_absolute
        end

        # Move to the previous line
        #
        sig { returns(String) }
        def previous_line
          cursor_up + cursor_horizontal_absolute
        end

        sig { returns(String) }
        def clear_to_end_of_line
          control('', 'K')
        end
      end
    end
  end
end
