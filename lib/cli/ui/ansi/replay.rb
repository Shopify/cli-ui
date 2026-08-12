# typed: true
# frozen_string_literal: true

require 'strscan'
require_relative 'terminal_width'

module CLI
  module UI
    module ANSI
      # Replays a captured terminal stream, collapsing repaints into the text
      # they settled on.
      #
      # Anything that repaints by moving the cursor -- spinners, spin groups,
      # progress bars, a prompt redrawing itself -- writes one frame per tick to
      # the stream. A capture of that stream (a log file, +StdoutRouter+'s
      # duplicate output, test output) therefore holds every frame. Stripping
      # the control sequences leaves them all side by side; applying them
      # collapses each repaint onto the last, which is what the screen showed.
      #
      # Operations that assume a viewport -- screen-relative positioning
      # (CUP), display erasure (ED), wrapping -- are ignored: a capture does
      # not record scrolling, so a screen coordinate has no buffer row to
      # map onto. The alternate screen (?1049) needs no viewport: what a
      # full-screen UI draws there is discarded on exit, as a terminal
      # discards it, never reaching scrollback. Commands outside the repaint
      # vocabulary -- character editing (ICH, DCH, ECH), scroll regions,
      # tab-stop setting, charset translation (SO/SI) -- are dropped without
      # effect. Each column holds one grapheme cluster, sized by
      # TerminalWidth.grapheme_width: a wide glyph owns two columns, and
      # overwriting either half blanks the other, as a terminal does.
      # Trailing whitespace on every line is trimmed from the result: a
      # terminal renders nothing there.
      module Replay
        # A run of characters a terminal displays: everything but C0 controls
        # and DEL.
        PRINTABLE = /[^\x00-\x1f\x7f]+/
        # A mark at the start of a printable run may continue the grapheme
        # before it: presentation sequences do not move the cursor or break
        # the glyph a terminal is assembling.
        LEADING_MARK = /\A\p{M}/
        # Every C0 control except ESC, plus DEL. A terminal displays none of
        # them: a few move the cursor, and simple_control drops the rest.
        SIMPLE_CONTROL = /[\x00-\x1a\x1c-\x1f\x7f]/
        # Parameter bytes, then intermediate bytes, then one final byte:
        # nearly every CSI sequence in a capture, matched in one pass. The
        # ones it can't match -- garbled, aborted, cut off, or carrying
        # embedded controls -- take the csi state's character loop, and both
        # paths funnel into the same apply, so neither can drift on dispatch.
        # The pass earns its keep: a 1.6MB capture holding 91k CSI sequences
        # replays a third again as slow without it (159ms to 206ms).
        CSI_BODY = /([\x30-\x3f]*)([\x20-\x2f]*)([\x40-\x7e])/
        # An OSC payload runs to its end: BEL or ST terminate it, CAN and SUB
        # abort it, and an aborting ESC starts a sequence of its own.
        OSC_PAYLOAD = /[^\x07\x18\x1a\e]+/
        # DCS, SOS, PM, and APC payloads end the same ways, BEL aside.
        CONTROL_STRING_PAYLOAD = /[^\x18\x1a\e]+/
        # A real terminal clamps cursor moves to its bounds and drops what
        # scrolls off. A replay has no viewport, so it caps instead: garbled
        # control codes can't inflate the screen, and real output is never held
        # back by the cap.
        MAX_DISTANCE = 1024
        MAX_COLUMN = 4096
        MAX_PADDING = 10_000
        # Terminals place tab stops every eight columns.
        TAB_STOP = 8
        # The second column of a wide glyph holds this marker: the glyph
        # owns both cells, but only the first contributes to the output.
        CONTINUATION = ''

        # A grid of lines with no viewport, each line an array of cells: one
        # grapheme cluster per column, a wide cluster owning its cell and a
        # CONTINUATION marker in the next, as terminal emulators store wide
        # glyphs. Height is unbounded because a capture has no scrollback to
        # lose, width because the writer has already truncated to the
        # terminal.
        class Screen
          #: -> void
          def initialize
            @lines = [[]] #: Array[Array[String]]
            @row = 0 #: Integer
            @col = 0 #: Integer
            @padding = 0 #: Integer
            @saved = [0, 0] #: Array[Integer]
            @conjured = {}.compare_by_identity #: Hash[Array[String], bool]
            @alternate = nil #: [Array[Array[String]], Integer, Integer, Array[Integer], Integer]?
          end

          #: (String text) -> void
          def write(text)
            line = materialize(@row)
            if text.ascii_only?
              # Every character in an ASCII printable run is one column
              # wide, so the whole run lands in one splice.
              put(line, text.chars)
            else
              # A cursor move can leave an implicit blank before a combining
              # mark. Materialize it so the mark has the same blank cell to
              # combine with that a terminal has.
              if text.match?(LEADING_MARK) && @col > line.length
                line.concat(Array.new(@col - line.length, ' '))
              end

              continuing_clusters(line, text).each do |cluster|
                # With no cell before the cursor, a terminal has nothing to
                # combine a leading mark with and displays no new cell for it.
                next if cluster.match?(LEADING_MARK)

                if TerminalWidth.grapheme_width(cluster) == 2
                  put(line, [cluster, CONTINUATION])
                else
                  put(line, [cluster])
                end
              end
            end
          end

          # The cursor may sit below the last line written, as it can in a
          # terminal; the gap only becomes real if something writes into it.
          #: (Integer rows) -> void
          def move_rows(rows)
            @row = (@row + rows).clamp(0, @lines.length - 1 + room)
          end

          #: (Integer cols) -> void
          def move_columns(cols)
            column(@col + cols)
          end

          # A column real output reached is never denied to a cursor move;
          # the cap holds back only columns a control sequence conjures.
          #: (Integer col) -> void
          def column(col)
            limit = MAX_COLUMN
            limit = [@lines.fetch(@row).length, limit].max if @row < @lines.length
            @col = col.clamp(0, limit)
          end

          # The gap a cursor move left behind is charged here, not to the
          # line feed: only the row the feed itself produces is free.
          #: -> void
          def line_feed
            materialize(@row)
            @row += 1
            @lines << [] while @lines.length <= @row
          end

          # A capture holds the writer's bare \n, but the tty driver's ONLCR
          # gave the terminal \r\n: a newline returns the column home too.
          #: -> void
          def newline
            line_feed
            @col = 0
          end

          #: -> void
          def carriage_return
            @col = 0
          end

          # A tab moves the cursor; only a later write makes the gap real.
          #: -> void
          def tab
            column(@col + TAB_STOP - (@col % TAB_STOP))
          end

          # DECSC/DECRC and their CSI twins. Restoring without a prior save
          # homes the cursor, as xterm does.
          #: -> void
          def save_cursor
            @saved = [@row, @col]
          end

          #: -> void
          def restore_cursor
            @row = @saved.fetch(0)
            @col = @saved.fetch(1)
          end

          #: (Integer mode) -> void
          def erase_line(mode)
            return if @row >= @lines.length

            # Modes a terminal doesn't define are ignored, not coerced to zero.
            line = @lines.fetch(@row)
            case mode
            when 0
              split_wide(line, @col)
              line.slice!(@col..)
            when 1
              erased = [@col + 1, line.length].min
              split_wide(line, erased)
              line.fill(' ', 0, erased)
            when 2 then line.clear
            end
          end

          #: (Integer count) -> void
          def insert_lines(count)
            materialize(@row)
            inserted = [count, room].min
            @padding += inserted
            @lines[@row, 0] = Array.new(inserted) { conjure }
          end

          # Deleting a conjured row hands its charge back: an insert and its
          # paired delete net to nothing.
          #: (Integer count) -> void
          def delete_lines(count)
            removed = @lines.slice!(@row, count)
            removed&.each { |line| @padding -= 1 if @conjured.delete(line) }
            @lines << [] if @lines.empty?
          end

          # The alternate screen holds a full-screen UI -- a prompt, a pager
          # -- whose content a terminal discards on exit: it never enters
          # scrollback. Entering saves the grid and cursor and swaps to a
          # scratch, as xterm's 1049 does; a second enter changes nothing.
          #: -> void
          def enter_alternate
            return if @alternate

            @alternate = [@lines, @row, @col, @saved, @padding]
            @lines = [[]]
            @row = 0
            @col = 0
            @saved = [0, 0]
          end

          # Leaving discards the scratch grid and restores the saved one,
          # cursor included. Restoring the padding count refunds whatever
          # the scratch spent: its rows are gone. An exit with no matching
          # enter changes nothing.
          #: -> void
          def exit_alternate
            stash = @alternate
            return unless stash

            @lines.each { |line| @conjured.delete(line) }
            @lines, @row, @col, @saved, @padding = stash
            @alternate = nil
          end

          # Trailing whitespace is trimmed from every line: a terminal renders
          # nothing there, and erasure and padding leave blanks behind that
          # were never content. A capture cut off inside the alternate screen
          # never saw the exit, but its content still never reached
          # scrollback: the saved grid is what the replay keeps.
          #: -> String
          def to_s
            lines = @lines
            if (stash = @alternate)
              lines = stash.fetch(0) #: as Array[Array[String]]
            end
            lines.map { |line| line.join.rstrip }.join("\n")
          end

          private

          # A presentation sequence can split one grapheme into separate
          # printable runs: "e\e[31m\u0301" is still one displayed cell.
          # Re-segment the new run with the glyph immediately before the
          # cursor. If they join, replace that glyph in place and return only
          # the clusters that remain to be written.
          #: (Array[String] line, String text) -> Array[String]
          def continuing_clusters(line, text)
            clusters = text.grapheme_clusters
            return clusters if @col.zero?

            previous_col = @col - 1
            previous_col -= 1 if CONTINUATION.equal?(line[previous_col])
            return clusters if previous_col.negative?

            previous = line[previous_col]
            return clusters unless previous

            old_width = CONTINUATION.equal?(line[previous_col + 1]) ? 2 : 1
            # The cursor can be moved into the second half of a wide glyph.
            # Only a complete glyph ending immediately before it can continue.
            return clusters unless previous_col + old_width == @col

            combined = "#{previous}#{text}".grapheme_clusters
            return clusters if combined.first == previous

            replacement = combined.shift.to_s
            replace_cluster(line, previous_col, old_width, replacement)
            combined
          end

          # Replacing a cluster never shifts the cells after it. A variation
          # selector can widen the preceding glyph, in which case it consumes
          # the next cell and advances the cursor just as the terminal does.
          #: (Array[String] line, Integer col, Integer old_width, String cluster) -> void
          def replace_cluster(line, col, old_width, cluster)
            mark_content(line)
            new_width = TerminalWidth.grapheme_width(cluster)
            span = [old_width, new_width].max
            split_wide(line, col + span)

            cells = new_width == 2 ? [cluster, CONTINUATION] : [cluster]
            cells.concat(Array.new(span - cells.length, ' '))
            line[col, span] = cells
            @col += new_width - old_width
          end

          # Splices cells into the current line at the cursor, one column
          # each.
          #: (Array[String] line, Array[String] cells) -> void
          def put(line, cells)
            mark_content(line)
            line.concat(Array.new(@col - line.length, ' ')) if @col > line.length
            split_wide(line, @col)
            split_wide(line, @col + cells.length)
            line[@col, cells.length] = cells
            @col += cells.length
          end

          # A conjured row that receives display content is content after all:
          # hand its charge back. A leading combining mark at column zero is
          # ignored before reaching here, so it cannot spend the padding cap.
          #: (Array[String] line) -> void
          def mark_content(line)
            @padding -= 1 if @conjured.delete(line)
          end

          # A cell boundary at col must not split a wide glyph: when col
          # lands on its CONTINUATION, both halves blank, as a terminal
          # blanks a glyph it can no longer show whole.
          #: (Array[String] line, Integer col) -> void
          def split_wide(line, col)
            return unless CONTINUATION.equal?(line[col])

            line[col - 1] = ' '
            line[col] = ' '
          end

          # Rows a control sequence conjured, as opposed to rows real output
          # produced. Only these are capped, and only while they stay blank:
          # a long capture is content, not garbage, and a conjured row that
          # text lands on stops counting.
          #: -> Integer
          def room
            [MAX_PADDING - @padding, 0].max
          end

          #: -> Array[String]
          def conjure
            line = [] #: Array[String]
            @conjured[line] = true
            line
          end

          # Fills in the rows a cursor move skipped, so every entry stays an
          # Array. The budget can overshoot by one move's worth: move_rows
          # clamps against the room left when it runs, which insert_lines may
          # since have spent.
          #: (Integer row) -> Array[String]
          def materialize(row)
            gap = row + 1 - @lines.length
            if gap.positive?
              @padding += gap
              @lines << conjure while @lines.length <= row
            end
            @lines.fetch(row)
          end
        end

        class << self
          # Replays +stream+ and returns what a terminal would have displayed.
          # Colors and other presentation sequences are dropped, as they are by
          # +ANSI.strip_codes+. The stream may arrive in any encoding --
          # captures are often read in binary mode -- and is decoded as UTF-8,
          # replacing bytes that don't decode.
          #
          # ==== Attributes
          #
          # - +stream+ - The captured terminal stream to replay
          #
          #: (String stream) -> String
          def render(stream)
            screen = Screen.new
            scanner = StringScanner.new(normalize(stream))
            state = :ground #: Symbol

            until scanner.eos?
              state =
                case state
                when :ground then ground(screen, scanner)
                when :escape then escape(screen, scanner)
                when :csi then csi(screen, scanner)
                when :osc then string_body(scanner, OSC_PAYLOAD)
                else string_body(scanner, CONTROL_STRING_PAYLOAD)
                end
            end

            screen.to_s
          end

          private

          # A capture arrives however it was read: binmode strings tagged
          # BINARY, mistagged text, other encodings. Columns are characters,
          # not bytes, so decode to UTF-8 and replace what doesn't decode.
          # Binary and mistagged strings usually hold UTF-8 bytes already,
          # so they are retagged rather than transcoded.
          #: (String stream) -> String
          def normalize(stream)
            if stream.encoding == Encoding::UTF_8
              stream.valid_encoding? ? stream : stream.scrub
            elsif stream.encoding == Encoding::ASCII_8BIT || !stream.valid_encoding?
              utf8 = stream.dup.force_encoding(Encoding::UTF_8)
              utf8.valid_encoding? ? utf8 : utf8.scrub
            else
              stream.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
            end
          end

          # The stream is parsed by the VT500-series state machine
          # (https://vt100.net/emu/dec_ansi_parser), one method per state,
          # each consuming what its state recognizes and returning the next.
          # From any state, CAN and SUB abort the sequence and a fresh ESC
          # starts one of its own; embedded C0 controls execute mid-sequence,
          # as they do on a real terminal. Only sequence bytes step character
          # by character: printable runs and string payloads move in bulk.
          # ANSI::CSI_SEQUENCE is no help here: it matches well-formed
          # sequences whole, while interpreting needs the parameters and
          # final apart, and must resolve the malformed rest the way a
          # terminal does.

          # Ground state: text and the cursor controls that carry it.
          #: (Screen screen, StringScanner scanner) -> Symbol
          def ground(screen, scanner)
            until scanner.eos?
              if (text = scanner.scan(PRINTABLE))
                screen.write(text)
              elsif (control = scanner.scan(SIMPLE_CONTROL))
                simple_control(screen, control)
              elsif scanner.skip(/\e\[/)
                # The transition nearly every escape in a capture takes,
                # folded into one step; the rest route through escape.
                return :csi
              else
                scanner.skip(/\e/)
                return :escape
              end
            end
            :ground
          end

          # Escape state: the character after ESC selects the sequence kind.
          # Finals that select commands a replay has no use for -- charset
          # designation and the rest of the nF and Fp families -- drop here.
          #: (Screen screen, StringScanner scanner) -> Symbol
          def escape(screen, scanner)
            until scanner.eos?
              case (char = scanner.getch.to_s)
              when '[' then return :csi
              when ']' then return :osc
              when 'P', 'X', '^', '_' then return :control_string
              when '7'
                screen.save_cursor
                return :ground
              when '8'
                screen.restore_cursor
                return :ground
              when 'D' # IND feeds a line, keeping the column
                screen.line_feed
                return :ground
              when 'E' # NEL starts the next line
                screen.newline
                return :ground
              when 'M' # RI reverse-feeds a line, keeping the column
                screen.move_rows(-1)
                return :ground
              when "\e" then next
              when "\x18", "\x1a" then return :ground
              when /[\x20-\x2f]/
                return escape_intermediate(screen, scanner)
              when SIMPLE_CONTROL then simple_control(screen, char)
              else return :ground
              end
            end
            :ground
          end

          # ESC intermediate state: collect through the final byte while
          # executing embedded C0 controls and ignoring DEL. Bulk-skipping this
          # tail would end the sequence at an embedded control, exposing its
          # final byte as printable text.
          #: (Screen screen, StringScanner scanner) -> Symbol
          def escape_intermediate(screen, scanner)
            until scanner.eos?
              case (char = scanner.getch.to_s)
              when /[\x30-\x7e]/ then return :ground
              when /[\x20-\x2f]/ then next
              when "\e" then return :escape
              when "\x18", "\x1a" then return :ground
              when SIMPLE_CONTROL then simple_control(screen, char)
              else return :ground
              end
            end
            :ground
          end

          # CSI state: parameter bytes, then intermediate bytes, then one
          # final byte. A garbled byte poisons the sequence -- it is consumed
          # through its final but not executed, the VT500's ignore state.
          #: (Screen screen, StringScanner scanner) -> Symbol
          def csi(screen, scanner)
            if scanner.scan(CSI_BODY)
              apply(screen, scanner[1].to_s, scanner[2].to_s, scanner[3].to_s)
              return :ground
            end

            params = +''
            intermediates = +''
            garbled = false #: bool
            until scanner.eos?
              case (char = scanner.getch.to_s)
              when /[\x40-\x7e]/
                apply(screen, params, intermediates, char) unless garbled
                return :ground
              when /[\x30-\x3f]/ then params << char
              when /[\x20-\x2f]/ then intermediates << char
              when "\e" then return :escape
              when "\x18", "\x1a" then return :ground
              when SIMPLE_CONTROL then simple_control(screen, char)
              else garbled = true
              end
            end
            :ground
          end

          # OSC and control-string states: a payload the terminal consumes
          # without displaying. Whatever ends it -- terminator, abort, or the
          # capture cutting off -- none of it reaches the screen. ST arrives
          # as an ESC and resolves through the escape state.
          #: (StringScanner scanner, Regexp payload) -> Symbol
          def string_body(scanner, payload)
            scanner.skip(payload)
            scanner.getch == "\e" ? :escape : :ground
          end

          # VT and FF feed a line but keep the column, as in xterm: the tty
          # driver's ONLCR translates only \n. Everything else -- BEL, NUL,
          # DEL, a standalone CAN -- falls through: a terminal displays
          # nothing for it.
          #: (Screen screen, String control) -> void
          def simple_control(screen, control)
            case control
            when "\n" then screen.newline
            when "\v", "\f" then screen.line_feed
            when "\r" then screen.carriage_return
            when "\t" then screen.tab
            when "\x08" then screen.move_columns(-1)
            end
          end

          #: (Screen screen, String params, String intermediates, String final) -> void
          def apply(screen, params, intermediates, final)
            # An intermediate byte selects a different command than the final
            # byte alone: \e[1 A is scroll-right, not cursor-up.
            return unless intermediates.empty?

            # DEC private modes (marked ?, like ?25l) change nothing a replay
            # tracks, except the alternate screen: a full-screen UI draws
            # there and a terminal discards it on exit, so it must not reach
            # the replayed scrollback either.
            if params.match?(/\A\?[\d;]*\z/)
              modes = params.delete_prefix('?').split(';')
              return unless modes.include?('1049')

              case final
              when 'h' then screen.enter_alternate
              when 'l' then screen.exit_alternate
              end
              return
            end

            # The remaining private markers (<, =, >, ?) select commands
            # outside the standard grammar: dispatch none of them.
            return unless params.match?(/\A[\d;]*\z/)

            # Sequences that assume a viewport -- absolute positioning (H, f),
            # erase-display (J) -- fall through: a replay has no bounds to
            # position against, and ignoring them keeps captured content.
            case final
            when 'A' then screen.move_rows(-distance(params))
            when 'B', 'e' then screen.move_rows(distance(params))
            when 'C', 'a' then screen.move_columns(distance(params))
            when 'D' then screen.move_columns(-distance(params))
            when 'E', 'F'
              screen.move_rows(final == 'E' ? distance(params) : -distance(params))
              screen.column(0)
            when 'G', '`' then screen.column(argument(params, 1) - 1)
            when 'K' then screen.erase_line(argument(params, 0))
            when 'L' then screen.insert_lines(distance(params))
            when 'M' then screen.delete_lines(distance(params))
            # A parameterized s is DECSLRM, setting scroll margins -- a
            # viewport operation -- not a save.
            when 's' then screen.save_cursor if params.empty?
            when 'u' then screen.restore_cursor
            end
          end

          # Movement counts default to 1, and terminals read an explicit 0 as 1 too.
          #: (String params) -> Integer
          def distance(params)
            argument(params, 1).clamp(1, MAX_DISTANCE)
          end

          #: (String params, Integer default) -> Integer
          def argument(params, default)
            value = params.split(';').first
            value.nil? || value.empty? ? default : value.to_i
          end
        end
      end
    end
  end
end
