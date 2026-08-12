# typed: true
# frozen_string_literal: true

require 'strscan'
require_relative 'ansi/terminal_width'

module CLI
  module UI
    module ANSI
      autoload :Replay, 'cli/ui/ansi/replay'
      private_constant :Replay

      ESC = "\x1b"
      # https://ghostty.org/docs/vt/concepts/sequences#csi-sequences
      CSI_SEQUENCE = /\x1b\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]/
      # https://ghostty.org/docs/vt/concepts/sequences#osc-sequences
      # OSC sequences can be terminated with either ST (\x1b\x5c) or BEL (\x07)
      OSC_SEQUENCE = /\x1b\][^\x07\x1b]*?(?:\x07|\x1b\x5c)/
      # An OSC 8 hyperlink: \x1b]8;params;URI, terminated like any OSC
      # sequence. One with a URI opens a link, one without closes it.
      # Anchored, to classify a whole sequence as yielded by each_token.
      HYPERLINK = /\A\x1b\]8;[^;]*;(?<uri>.*)(?:\x07|\x1b\x5c)\z/m
      HYPERLINK_END = "\x1b]8;;\x1b\x5c"
      # Any whole control sequence, for walking a string as alternating
      # sequence and text runs.
      SEQUENCE = Regexp.union(CSI_SEQUENCE, OSC_SEQUENCE)
      # A CSI or OSC introducer whose sequence runs to the end of the
      # string without a terminator — usually one sliced open by an
      # upstream cut. Treating it as a sequence keeps its bytes out of
      # width measurements and truncation windows.
      UNTERMINATED_SEQUENCE = /\x1b[\[\]][^\x1b]*\z/
      TEXT_RUN = /[^\x1b]+/
      class << self
        # Yields str as alternating runs of :sequence (one whole CSI or OSC
        # sequence) and :text (everything between them). Sequences never
        # straddle tokens, so a consumer that measures or cuts only at
        # token boundaries cannot slice one open. A CSI or OSC sequence
        # left unterminated at the end of the string is yielded as one
        # :sequence token; any other stray ESC is yielded as text.
        #
        #: (String str) ?{ (Symbol kind, String token) -> void } -> Enumerator[[Symbol, String]]?
        def each_token(str, &block)
          return to_enum(:each_token, str) unless block_given?

          scanner = StringScanner.new(str)
          until scanner.eos?
            if (sequence = scanner.scan(SEQUENCE) || scanner.scan(UNTERMINATED_SEQUENCE))
              yield(:sequence, sequence)
            elsif (text = scanner.scan(TEXT_RUN))
              yield(:text, text)
            else
              yield(:text, scanner.getch.to_s)
            end
          end
        end

        # The number of terminal columns str occupies when printed: control
        # sequences take none, and each grapheme cluster (not codepoint:
        # 👩‍💻 is one cluster) is measured by grapheme_width.
        #
        #: (String str) -> Integer
        def printing_width(str)
          # ASCII fast paths. Every ASCII grapheme cluster is one character
          # wide except \n and \r, which are zero, so counting stands in for
          # the cluster walk; with no ESC there are no sequences to skip and
          # the whole string can be counted without tokenizing.
          if str.ascii_only? && !str.include?(ESC)
            return str.length - str.count("\n\r")
          end

          width = 0 #: Integer
          each_token(str) do |kind, token|
            next unless kind == :text

            if token.ascii_only?
              width += token.length - token.count("\n\r")
            else
              token.grapheme_clusters.each do |cluster|
                width += grapheme_width(cluster)
              end
            end
          end
          width
        end

        # The number of terminal columns one grapheme cluster occupies.
        #
        #: (String cluster) -> Integer
        def grapheme_width(cluster)
          TerminalWidth.grapheme_width(cluster)
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

        # Replays the viewport-independent cursor controls in a captured
        # terminal stream, so repaints (spinners, progress bars) collapse
        # onto their final state instead of accumulating one frame per tick.
        #
        # Where +strip_codes+ deletes control sequences, this applies them.
        # Operations that assume a viewport -- screen-relative positioning,
        # display erasure, wrapping -- are ignored: a capture does not
        # record scrolling, so screen coordinates have no buffer row to map
        # onto. Alternate-screen content (a full-screen prompt, a pager) is
        # discarded on exit, as a terminal discards it. Commands a repaint
        # has no use for, from character editing to charset translation,
        # are dropped without effect. The stream is decoded as UTF-8
        # whatever its tagged encoding, replacing bytes that don't decode.
        # Columns hold one grapheme cluster each, using Unicode terminal
        # widths so wide glyphs keep their two columns when overwritten.
        # Trailing whitespace on every line is trimmed: a terminal renders
        # nothing there.
        #
        # ==== Attributes
        #
        # - +str+ - The captured terminal stream to replay
        #
        #: (String str) -> String
        def replay(str)
          Replay.render(str)
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

        # Renders text as an OSC 8 hyperlink to url
        #
        #: (String url, String text) -> String
        def hyperlink(url, text)
          "\x1b]8;;#{url}\x1b\x5c#{text}#{HYPERLINK_END}"
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
