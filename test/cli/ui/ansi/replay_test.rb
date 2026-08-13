# frozen_string_literal: true

require 'test_helper'
require 'cli/ui/ansi'

module CLI
  module UI
    module ANSI
      class ReplayTest < Minitest::Test
        def test_plain_text_is_untouched
          assert_equal("one\ntwo", Replay.render("one\ntwo"))
        end

        def test_drops_color_cursor_visibility_and_hyperlinks
          raw = "\e[?25l\e[0;33m*\e[0m #{CLI::UI.link("https://shopify.dev", "docs", format: false)}\e[?25h"

          assert_equal('* docs', Replay.render(raw))
        end

        def test_carriage_return_overwrites_in_place
          assert_equal('byelo', Replay.render("hello\rbye"))
          assert_equal('bye', Replay.render("hello\r\e[Kbye"))
        end

        def test_cursor_movement_positions_text
          assert_equal('    x', Replay.render("\e[4Cx"))
          assert_equal('axb', Replay.render("a b\e[2Dx"))
          assert_equal('xb', Replay.render("ab\e[1Gx"))
        end

        # A terminal's cursor can sit below everything written so far.
        def test_cursor_can_move_below_written_output
          assert_equal("a\n b", Replay.render("a\e[Bb"))
          assert_equal("a\nb", Replay.render("a\e[Eb"))
        end

        def test_erase_line_modes
          assert_equal('keep', Replay.render("keep drop\e[5G\e[0K"))
          assert_equal('     drop', Replay.render("keep drop\e[5G\e[1K"))
          assert_equal('', Replay.render("keep drop\e[2K"))
        end

        # Trailing whitespace is trimmed from every line: a terminal renders
        # nothing there, so blanks left by padding or erasure are not content.
        def test_trailing_whitespace_is_trimmed
          assert_equal('ab', Replay.render('ab   '))
          assert_equal("a\n  b", Replay.render("a  \n  b  "))
        end

        # Messages printed above a running spin group arrive as inserted lines.
        def test_insert_and_delete_lines
          assert_equal("note\nkept", Replay.render("kept\e[1G\e[1Lnote\n"))
          assert_equal('second', Replay.render("first\nsecond\e[2A\e[1M"))
        end

        # Inserting while the cursor is still below the written output must not
        # punch holes into the screen.
        def test_insert_below_written_output
          assert_equal("\n\nx\n", Replay.render("\e[2B\e[Lx"))
        end

        def test_tab_advances_to_the_next_tab_stop
          assert_equal('a       b', Replay.render("a\tb"))
          assert_equal('axttttttb', Replay.render("a\tb\e[2Gxtttttt"))
        end

        def test_bell_prints_nothing
          assert_equal('xy', Replay.render("x\ay"))
        end

        def test_cursor_save_and_restore
          assert_equal("AC\nB", Replay.render("A\e[s\nB\e[uC"))
          assert_equal("AC\nB", Replay.render("A\e7\nB\e8C"))
        end

        # IND and RI feed and reverse-feed a line keeping the column, and
        # NEL starts a new one: escape-level movement a repaint can use.
        def test_escape_line_movement
          assert_equal("a\n b", Replay.render("a\eDb"))
          assert_equal("a\nb", Replay.render("a\eEb"))
          assert_equal("ax\nc", Replay.render("ab\nc\eMx"))
        end

        # CSI s with parameters is DECSLRM, setting scroll margins, not a
        # cursor save; margins are viewport-dependent and ignored.
        def test_parameterized_save_cursor_is_not_misread
          assert_equal('abZY', Replay.render("ab\e[sX\e[10;70sY\e[uZ"))
        end

        # A restore with no prior save homes the cursor, as xterm does.
        def test_restore_without_save_homes_the_cursor
          assert_equal("?cz\nab", Replay.render("xyz\nab\e[u?c"))
        end

        # A stray ESC aborts nothing but itself: the sequence after it survives.
        def test_stray_escape_does_not_eat_a_following_sequence
          assert_equal('     x', Replay.render("\e\e[5Cx"))
        end

        # An intermediate byte or a private parameter marker selects a
        # different command than the final byte alone: \e[1 A is
        # scroll-right, not cursor-up.
        def test_nonstandard_csi_sequences_are_not_dispatched
          assert_equal("x\nyz", Replay.render("x\ny\e[1 Az"))
          assert_equal('x', Replay.render("\e[>5Cx"))
        end

        # DCS, SOS, PM, and APC payloads are consumed, never displayed.
        def test_control_string_payloads_do_not_leak
          assert_equal('ab', Replay.render("a\ePpayload\e\\b"))
          assert_equal('ab', Replay.render("a\e_hidden\e\\b"))
          assert_equal('ab', Replay.render("a\ePstuff\x18b"))
          assert_equal('a', Replay.render("a\ePcut off"))
        end

        def test_nonprinting_controls_are_dropped
          assert_equal('ab', Replay.render("a\x18b"))
          assert_equal('ab', Replay.render("a\x00b"))
          assert_equal('ab', Replay.render("a\x7fb"))
        end

        # VT and FF feed a line but keep the column: the tty driver's ONLCR
        # translation, which turns \n into \r\n, applies to neither.
        def test_vertical_tab_and_form_feed_advance_a_line
          assert_equal("a\n b", Replay.render("a\vb"))
          assert_equal("a\n b", Replay.render("a\fb"))
        end

        # A C0 control embedded in a CSI sequence is executed and collection
        # continues, as a real terminal's parser does.
        def test_embedded_controls_execute_inside_csi_sequences
          assert_equal('red', Replay.render("\e[3\a1mred"))
          assert_equal('red', Replay.render("\e[3\b1mred"))
          assert_equal("x\nred", Replay.render("x\e[3\n1mred"))
        end

        # Controls embedded after an ESC intermediate do not end its sequence:
        # C0 controls execute, DEL is ignored, and the eventual final is still
        # consumed.
        def test_embedded_controls_do_not_end_escape_intermediate_sequences
          assert_equal('az', Replay.render("ab\e(\bBz"))
          assert_equal('Az', Replay.render("A\e(\x7fBz"))
        end

        # A parameter byte arriving after an intermediate puts a terminal in
        # its ignore state: the sequence is consumed but not executed.
        def test_out_of_order_csi_bytes_ignore_the_sequence
          assert_equal('red', Replay.render("\e[1 5mred"))
        end

        # Erase-line modes a terminal doesn't define do nothing.
        def test_invalid_erase_line_modes_are_ignored
          assert_equal('keep drop', Replay.render("keep drop\e[5G\e[3K"))
        end

        # The alternate screen holds a full-screen UI -- a prompt, a pager --
        # that a terminal discards on exit: its content never enters
        # scrollback, so a replay withholds it too, cursor restored to where
        # the main screen left it.
        def test_alternate_screen_content_is_discarded
          ['47', '1047', '1049'].each do |mode|
            assert_equal(
              'before after',
              Replay.render("before \e[?#{mode}hfull-screen ui\e[?#{mode}lafter"),
              "DEC private mode #{mode}",
            )
          end
          # A capture cut off inside the alternate screen never saw the
          # exit, but its content still never reached scrollback.
          assert_equal('kept', Replay.render("kept\e[?1049hlost"))
          # An unmatched exit and a doubled enter change nothing.
          assert_equal('ab', Replay.render("a\e[?1049lb"))
          assert_equal('ab', Replay.render("a\e[?1049h\e[?1049hx\e[?1049lb"))
          # DECSET and DECRST apply every mode in a semicolon-separated list.
          assert_equal('ab', Replay.render("a\e[?25;1049hLOST\e[?25;1049lb"))
        end

        # StdoutRouter's in_alternate_screen re-prints everything captured
        # so far inside the alternate screen; a replay that ignored ?1049
        # would show that content twice.
        def test_alternate_screen_does_not_duplicate_a_reprinted_capture
          prior = "✔ one\n✔ two\n"
          stream = prior +
            ANSI.enter_alternate_screen + prior + '? Choose: ' +
            ANSI.exit_alternate_screen + 'done'

          assert_equal("✔ one\n✔ two\ndone", Replay.render(stream))
        end

        # Absolute positioning and display erasure are viewport-relative, and
        # a capture does not record scrolling: there is no way to know which
        # buffer row was screen row 1. Ignoring them is policy, not oversight;
        # mapping \e[H to row zero would overwrite scrolled-off content.
        def test_viewport_dependent_sequences_are_ignored
          assert_equal("old\nlinenew", Replay.render("old\nline\e[Hnew"))
          assert_equal("old\nlinenew", Replay.render("old\nline\e[2;3fnew"))
          assert_equal('kept', Replay.render("kept\e[2J"))
        end

        def test_viewport_dependent_sequences_are_reported
          sequences = [
            "\e[H",       # CUP
            "\e[2;3f",    # HVP
            "\e[3d",      # VPA
            "\e[2J",      # ED
            "\e[2S",      # SU
            "\e[2T",      # SD
            "\e[1;20r",   # DECSTBM
            "\e[10;70s",  # DECSLRM
            "\e[2 @",     # SL
            "\e[2 A",     # SR
          ]

          sequences.each do |sequence|
            diagnostics = {}

            ANSI.replay("kept#{sequence}", diagnostics: diagnostics)

            assert_equal(true, diagnostics[:viewport_operations_seen], sequence.inspect)
          end
        end

        def test_supported_repaint_sequences_do_not_report_viewport_operations
          diagnostics = {}

          ANSI.replay("one\ntwo\e[1A\e[1G\e[2Kdone", diagnostics: diagnostics)

          assert_empty(diagnostics)
        end

        def test_unknown_and_incomplete_escapes_are_dropped
          assert_equal('text', Replay.render("\e(Btext\e"))
          assert_equal('ok', Replay.render("ok\e[31"))
          assert_equal('ok', Replay.render("ok\e]0;a title"))
        end

        # CAN aborts the sequence; what follows is text again.
        def test_cancelled_osc_releases_following_text
          assert_equal('ok visible', Replay.render("ok \e]0;title\x18visible"))
        end

        # An aborted sequence's payload was never displayed, and an aborting
        # ESC starts its own sequence.
        def test_aborted_sequences_do_not_leak_their_payload
          assert_equal('ok red', Replay.render("ok \e]0;title\e[31mred"))
          assert_equal('m', Replay.render("\e[3\x18m"))
          assert_equal('  x', Replay.render("\e[3\e[2Cx"))
        end

        # Captures are routinely read in binary mode, and columns are
        # characters, not bytes: every input is decoded as UTF-8, replacing
        # what doesn't decode.
        def test_input_is_decoded_as_utf8
          assert_equal('éQ', Replay.render("éx\e[2GQ".b))
          assert_equal('café', Replay.render('café'.dup.force_encoding(Encoding::US_ASCII)))
          assert_equal('café', Replay.render('café'.encode(Encoding::ISO_8859_1)))
          assert_equal('a�b', Replay.render("a\xFFb".b))
        end

        # Wide glyphs occupy two columns, so column-addressed writes land
        # where the terminal put the text. A ZWJ sequence is one cluster:
        # one glyph, two columns.
        def test_wide_glyphs_occupy_two_columns
          assert_equal('🔧X', Replay.render("🔧b\e[3GX"))
          assert_equal('ab', Replay.render("👩‍💻\rab"))
        end

        # Overwriting either half of a wide glyph blanks the other, as a
        # terminal blanks a glyph it can no longer show whole.
        def test_overwriting_half_a_wide_glyph_blanks_the_other_half
          assert_equal('a x', Replay.render("🔧x\ra"))
          assert_equal('🔧', Replay.render("ab\r🔧"))
        end

        # A combining mark rides its base character: one cluster, one column.
        def test_combining_marks_share_their_column
          assert_equal('xZ', Replay.render("e\u0301Z\rx"))
          assert_equal("e\u0301X", Replay.render("e\u0301Z\e[2GX"))
        end

        # Presentation sequences do not interrupt a grapheme a terminal is
        # assembling. Re-segmenting across them also preserves a wide base and
        # lets a variation selector widen the glyph before the next write.
        def test_graphemes_continue_across_presentation_sequences
          assert_equal("e\u0301X", Replay.render("e\e[31m\u0301Z\e[2GX"))
          assert_equal("🔧\u0301X", Replay.render("🔧\e[31m\u0301b\e[3GX"))
          assert_equal('⚠️X', Replay.render("⚠\e[31m️b\e[3GX"))
          assert_equal('👩‍💻X', Replay.render("👩\e[31m‍💻b\e[3GX"))
        end

        # A leading mark with no preceding cell prints nothing. If a cursor
        # move left an implicit blank before it, the mark combines with that
        # blank without advancing the cursor.
        def test_leading_combining_marks_need_a_preceding_cell
          assert_equal('Z', Replay.render("\u0301Z"))
          assert_equal("a \u0301Z", Replay.render("a\e[C\u0301Z"))
        end

        # The writer's own output can run past MAX_COLUMN; the cap holds back
        # only columns that control sequences conjure.
        def test_long_lines_keep_relative_movement_working
          line = 'x' * (Replay::MAX_COLUMN + 904)

          replayed = Replay.render("#{line}\b\bX")

          assert_equal(line.length, replayed.length)
          assert_equal(line.length - 2, replayed.index('X'))
        end

        def test_write_once_rows_stay_compact_until_they_are_edited
          screen = Replay::Screen.new
          rows = ['x' * 80, '界' * 40, '👩‍💻' * 40]
          100.times do |index|
            screen.write(rows.fetch(index % rows.length))
            screen.erase_line(0)
            screen.newline
          end

          lines = screen.instance_variable_get(:@lines)
          assert(lines.all?(String))

          screen.move_rows(-1)
          screen.carriage_return
          screen.write('y')

          assert_instance_of(Array, lines.fetch(-2))
          assert(lines.each_with_index.all? { |line, index| index == 99 || line.is_a?(String) })
        end

        def test_control_conjured_rows_are_bounded
          moves = Replay.render(("\e[9999999B" * 1000) + 'x')
          inserts = Replay.render("\e[1024L" * 200)
          # A newline after a cursor move must not hand the budget back.
          interleaved = Replay.render("\e[1024B\n" * 20)

          assert_operator(moves.lines.length, :<=, Replay::MAX_PADDING + 1)
          assert_operator(inserts.lines.length, :<=, Replay::MAX_PADDING + 1)
          assert_operator(interleaved.lines.length, :<=, Replay::MAX_PADDING + 20)
          assert_equal(Replay::MAX_COLUMN + 1, Replay.render("#{"\e[1024C" * 8}x").length)
        end

        # Ordinary output is content, not garbage: it never spends the cap.
        def test_long_captures_keep_insert_line_working
          capture = "line\n" * (Replay::MAX_PADDING + 10)

          replayed = Replay.render("#{capture}kept\e[1G\e[1Lnote\n")

          assert_equal("note\nkept", replayed.lines.last(2).join.chomp)
        end

        # Every message printed above a running spin group inserts a row
        # that immediately receives text: content, not padding. Were those
        # rows charged to the cap, inserts past it would silently no-op and
        # later messages would overwrite the task lines below.
        def test_puts_above_messages_are_never_charged_to_the_cap
          tasks = "✓ first\n✓ second"
          notes = "\e[1Lnote\n" * (Replay::MAX_PADDING + 5)

          replayed = Replay.render("#{tasks}\e[1A\e[1G#{notes}")

          assert_equal(['✓ first', '✓ second'], replayed.lines.last(2).map(&:chomp))
        end

        # A capture can hold anything: truncated sequences, binary noise,
        # aborts landing mid-collection. Whatever the bytes, a replay must
        # not raise, must return valid UTF-8, and must not leak control
        # bytes into the output.
        def test_fuzz_arbitrary_streams_replay_safely_and_both_csi_paths_agree
          rng = Random.new(20260811)
          fragments = [
            "\e[",
            "\e]",
            "\eP",
            "\e\\",
            "\e",
            "\x18",
            "\x1a",
            "\a",
            "\r",
            "\n",
            "\t",
            ';',
            '?',
            ' ',
            'm',
            'A',
            'K',
            'text',
            'é',
            '⠧',
            "\e[31m",
            "\e[2A",
            "\e[1G",
            "\e[2K",
            "\e[1L",
            "\e[2M",
            "\e[s",
            "\e[u",
            "\e[3G",
            "\e[2C",
            "\b",
            "\e[?47h",
            "\e[?47l",
            "\e[?1047h",
            "\e[?1047l",
            "\e[?1049h",
            "\e[?1049l",
          ]
          streams = [
            "hello\r\e[Kbye",
            "a b\e[2Dx\e[1Gy",
            "\e[?25l\e[0;33m* done\e[0m\e[?25h",
            "x\ny\e[1 Az",
            "\e[3\a1mred",
            "ok\e[31",
            "⚠\e[31m️b\e[3GX",
            "👩\e[31m‍💻b\e[3GX",
            "界Z\e[2GX",
            "\u0301Z",
            "a\e[C\u0301Z",
            "界\tX",
          ]
          3000.times do
            stream = ''.b
            rng.rand(40..120).times do
              stream << (rng.rand(3).zero? ? rng.bytes(rng.rand(1..6)) : fragments.sample(random: rng).b)
            end
            streams << stream
          end

          expected = streams.map do |stream|
            replayed = Replay.render(stream)

            assert_predicate(replayed, :valid_encoding?)
            assert_nil(replayed[/[\x00-\x09\x0b-\x1f\x7f]/], "control byte leaked replaying #{stream.inspect}")
            replayed
          end

          original = Replay::CSI_BODY
          Replay.send(:remove_const, :CSI_BODY)
          Replay.const_set(:CSI_BODY, /(?!)/) # never matches

          streams.each_with_index do |stream, index|
            assert_equal(expected.fetch(index), Replay.render(stream), "CSI paths diverged replaying #{stream.inspect}")
          end

          Replay.send(:remove_const, :CSI_BODY)
          Replay.const_set(:CSI_BODY, original)

          original_screen = Replay::Screen
          forced_cell_screen = Class.new(original_screen) do
            def write(text)
              materialize(@row)
              promote(@row)
              super
            end

            def erase_line(mode)
              promote(@row) if @row < @lines.length
              super
            end
          end
          Replay.send(:remove_const, :Screen)
          Replay.const_set(:Screen, forced_cell_screen)

          streams.each_with_index do |stream, index|
            assert_equal(expected.fetch(index), Replay.render(stream), "write paths diverged replaying #{stream.inspect}")
          end
        ensure
          if original && Replay::CSI_BODY != original
            Replay.send(:remove_const, :CSI_BODY)
            Replay.const_set(:CSI_BODY, original)
          end
          if original_screen && Replay::Screen != original_screen
            Replay.send(:remove_const, :Screen)
            Replay.const_set(:Screen, original_screen)
          end
        end

        def test_replays_a_spin_group_to_one_line_per_task
          repaint = Queue.new
          sink_class = Class.new(StringIO) do
            define_method(:print) do |*args|
              super(*args).tap do
                if !defined?(@repaint_signaled) && string.match?(/\e\[\d*A/)
                  @repaint_signaled = true
                  2.times { repaint << true }
                end
              end
            end
          end
          sink = sink_class.new
          CLI::UI::StdoutRouter.ensure_activated
          group = CLI::UI::SpinGroup.new(auto_debrief: false)
          group.add('first') { repaint.pop(timeout: 2) }
          group.add('second') { repaint.pop(timeout: 2) }
          assert(group.wait(to: sink))
          out = sink.string

          replayed = ANSI.replay(out).lines.map(&:chomp).reject(&:empty?)

          assert_match(/\e\[\d*A/, out, 'expected the raw capture to hold cursor repaints')
          assert_equal(2, replayed.length)
          assert_match(/first/, replayed.fetch(0))
          assert_match(/second/, replayed.fetch(1))
        end
      end
    end
  end
end
