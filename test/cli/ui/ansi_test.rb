# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class ANSITest < Minitest::Test
      def test_sgr
        assert_equal("\x1b[1;34m", ANSI.sgr('1;34'))
      end

      def test_hyperlink
        assert_equal("\e]8;;https://example.com\e\\text\e]8;;\e\\", ANSI.hyperlink('https://example.com', 'text'))
      end

      def test_printing_width
        assert_equal(4, ANSI.printing_width("\x1b[38;2;100;100;100mtest\x1b[0m"))
        assert_equal(0, ANSI.printing_width(''))

        # Emoji occupy two columns, matching what Truncater has always
        # assumed. A ZWJ sequence is one grapheme cluster, so one emoji.
        assert_equal(4, ANSI.printing_width('>🔧<'))
        assert_equal(2, ANSI.printing_width('👩‍💻'))

        # Newlines and combining marks occupy no columns.
        assert_equal(2, ANSI.printing_width("a\nb"))
        assert_equal(1, ANSI.printing_width("e\u0301"))

        # Mixed sequences, emoji, and ASCII in one string.
        assert_equal(5, ANSI.printing_width("\e[31m\u{1f527} ok\e[0m"))

        assert_equal(4, ANSI.printing_width(UI.link('url', 'text')))
      end

      def test_printing_width_covers_wide_glyphs_beyond_the_core_emoji_block
        # BMP emoji outside the U+1F300 block, SMP emoji beyond U+1F5FF,
        # and CJK are all two columns wide.
        assert_equal(2, ANSI.printing_width('✅'))
        assert_equal(2, ANSI.printing_width('⭐'))
        assert_equal(2, ANSI.printing_width('🚀'))
        assert_equal(2, ANSI.printing_width('🛒'))
        assert_equal(2, ANSI.printing_width('😀'))
        assert_equal(4, ANSI.printing_width('漢字'))

        # VS16 asks for emoji presentation: U+26A0 alone is a narrow text
        # glyph, but ⚠️ (U+26A0 + VS16) renders two columns wide. This is
        # Glyph::WARNING's form.
        assert_equal(1, ANSI.printing_width("\u{26a0}"))
        assert_equal(2, ANSI.printing_width("\u{26a0}\u{fe0f}"))

        # A flag is two regional indicators forming one wide cluster.
        assert_equal(2, ANSI.printing_width('🇨🇦'))

        # Narrow neighbours of wide ranges stay narrow.
        assert_equal(1, ANSI.printing_width('✓'))
        assert_equal(1, ANSI.printing_width('⭑'))
      end

      def test_ascii_measurement_does_not_tokenize
        ANSI.expects(:each_token).never

        assert_equal(5, ANSI.printing_width('plain'))
      end

      def test_each_token_rejoins_every_input
        rng = Random.new(20260812)
        fragments = [
          'plain',
          ' ',
          "\n",
          '漢字',
          '👩‍💻',
          "e\u0301",
          "\e[31m",
          "\e[0m",
          "\e[?25l",
          "\e[K",
          "\e]8;;https://example.com\e\\",
          ANSI::HYPERLINK_END,
          "\e",
        ]

        500.times do
          input = Array.new(rng.rand(0..30)) { fragments.sample(random: rng) }.join
          rejoined = ANSI.each_token(input).map { |_kind, token| token }.join

          assert_equal(input, rejoined)
        end
      end

      def test_each_token_yields_whole_sequences_and_text
        tokens = []
        ANSI.each_token("a\e[?25l\e]8;;https://x\e\\b") { |kind, token| tokens << [kind, token] }
        assert_equal(
          [
            [:text, 'a'],
            [:sequence, "\e[?25l"],
            [:sequence, "\e]8;;https://x\e\\"],
            [:text, 'b'],
          ],
          tokens,
        )
      end

      def test_each_token_without_a_block_returns_an_enumerator
        enum = ANSI.each_token("a\e[31mb")

        assert_kind_of(Enumerator, enum)
        assert_equal([[:text, 'a'], [:sequence, "\e[31m"], [:text, 'b']], enum.to_a)
        assert_equal([], ANSI.each_token('').to_a)
      end

      def test_each_token_yields_stray_escape_as_text
        tokens = []
        ANSI.each_token("a\eb") { |kind, token| tokens << [kind, token] }
        assert_equal([[:text, 'a'], [:text, "\e"], [:text, 'b']], tokens)
      end

      def test_each_token_yields_a_trailing_unterminated_sequence_whole
        # A sequence sliced open by an upstream cut runs to the end of the
        # string with no terminator. It stays one zero-width token instead
        # of being counted (and sliced again) as text.
        assert_equal([[:text, 'a'], [:sequence, "\e[31"]], ANSI.each_token("a\e[31").to_a)
        assert_equal([[:sequence, "\e]8;;http://x"]], ANSI.each_token("\e]8;;http://x").to_a)

        # Mid-string, an unterminated sequence is still text: only at the
        # end of the string is a missing terminator unambiguous.
        assert_equal(
          [[:text, "\e"], [:text, '[31'], [:sequence, "\e[0m"]],
          ANSI.each_token("\e[31\e[0m").to_a,
        )
      end

      # CSI sequences aren't required to carry parameters (\e[K, \e[m), and
      # private-mode sequences mark theirs with ? (\e[?25l). None of them
      # print anything.
      def test_printing_width_of_parameterless_and_private_sequences_is_zero
        assert_equal(1, ANSI.printing_width("\e[?25lx\e[K"))
        assert_equal(4, ANSI.printing_width("\e[mtest\e[0m"))
      end

      def test_strip_codes_removes_parameterless_and_private_sequences
        assert_equal('x', ANSI.strip_codes("\e[?25lx\e[K"))
        assert_equal('shown', ANSI.strip_codes("#{ANSI.hide_cursor}shown#{ANSI.show_cursor}"))
        assert_equal('saved', ANSI.strip_codes("#{ANSI.cursor_save}saved#{ANSI.cursor_restore}"))
      end

      def test_strip_codes_preserves_text_between_osc8_hyperlinks
        hyperlink = CLI::UI.link('https://example.com', 'text', format: false)
        input = "Before #{hyperlink} after"

        result = CLI::UI::ANSI.strip_codes(input)

        assert_equal('Before text after', result)
      end

      def test_strip_codes_with_osc9_progress_and_osc8_hyperlink
        # Test OSC 9 progress indicator (BEL-terminated) followed by OSC 8 hyperlink (ST-terminated)
        # This is the actual bug found in Ghostty terminal
        progress = "#{CLI::UI::ProgressReporter::Reporter::OSC}9;4;#{CLI::UI::ProgressReporter::Reporter::INDETERMINATE};#{CLI::UI::ProgressReporter::Reporter::ST}"
        hyperlink = CLI::UI.link('https://example.com/repo/pull/12345', 'PR#12345', format: false)
        input = "Before #{progress} Created #{hyperlink} After"

        result = CLI::UI::ANSI.strip_codes(input)

        # Should preserve all visible text
        assert_equal('Before  Created PR#12345 After', result)
      end

      def test_line_skip_with_shift
        next_line_expected = "\e[1B\e[1G"
        previous_line_expected = "\e[1A\e[1G"

        assert_equal(next_line_expected, ANSI.next_line)
        assert_equal(previous_line_expected, ANSI.previous_line)

        CLI::UI::OS.stubs(:current).returns(CLI::UI::OS::WINDOWS)

        assert_equal("#{next_line_expected}\e[1D", ANSI.next_line)
        assert_equal("#{previous_line_expected}\e[1D", ANSI.previous_line)
      end
    end
  end
end
