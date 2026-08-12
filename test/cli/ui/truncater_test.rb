# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class TruncaterTest < Minitest::Test
      MAN     = "\u{1f468}" # width=2
      COOKING = "\u{1f373}" # width=2
      ZWJ     = "\u{200d}"  # width=complicated

      MAN_COOKING = MAN + ZWJ + COOKING # width=2

      def test_truncate
        assert_example(3, 'foobar', "fo\x1b[0m…")
        assert_example(5, 'foobar', "foob\x1b[0m…")
        assert_example(6, 'foobar', 'foobar')
        assert_example(6, "foo\x1b[31mbar\x1b[0m", "foo\x1b[31mbar\x1b[0m")
        assert_example(6, "\x1b[31mfoobar", "\x1b[31mfoobar")
        assert_example(3, MAN_COOKING * 2, MAN_COOKING + Truncater::TRUNCATED)
        assert_example(3, 'A' + MAN_COOKING, 'A' + MAN_COOKING)
        assert_example(3, 'AB' + MAN_COOKING, 'AB' + Truncater::TRUNCATED)
      end

      def test_truncate_never_slices_a_sequence
        # Private-mode (\x1b[?25l) and parameterless (\x1b[K) sequences pass
        # through whole and spend no width; those past the cut are dropped.
        assert_example(3, "\x1b[?25lfoobar\x1b[K", "\x1b[?25lfo" + Truncater::TRUNCATED)
      end

      def test_truncate_treats_a_trailing_unterminated_sequence_as_a_sequence
        # A sequence already sliced open (by an upstream cut, say) spends
        # no width: past the cut it drops, and alone it passes unchanged.
        assert_example(3, "foobar\x1b]8;;http://x", 'fo' + Truncater::TRUNCATED)
        input = "\x1b]8;;http://x  no-terminator"
        assert_example(5, input, input)
      end

      def test_truncate_measures_by_column_not_character
        # Each 🌈 is one character but two columns; a character-count
        # shortcut would pass these through six columns wide.
        assert_example(1, '🔧', Truncater::TRUNCATED)
        assert_example(3, '🌈🌈🌈', '🌈' + Truncater::TRUNCATED)
      end

      def test_truncate_cuts_before_a_line_break
        # printing_width counts a newline as zero columns, but a truncated
        # string must stay one line: the cut lands before the break.
        assert_example(3, "ab\ncd", 'ab' + Truncater::TRUNCATED)
        assert_example(3, "🌈\ncd", '🌈' + Truncater::TRUNCATED)
      end

      def test_truncate_does_not_count_other_zero_width_clusters
        zero_width = "\u200b"
        ANSI.stubs(:grapheme_width).returns(1)
        ANSI.stubs(:grapheme_width).with(zero_width).returns(0)

        assert_example(3, "a#{zero_width}bcde", "a#{zero_width}b" + Truncater::TRUNCATED)
      end

      def test_truncate_closes_an_open_hyperlink
        link = "\x1b]8;;https://example.com\x1b\\foobar\x1b]8;;\x1b\\"
        assert_example(
          3,
          link,
          "\x1b]8;;https://example.com\x1b\\fo" + ANSI::HYPERLINK_END + Truncater::TRUNCATED,
        )
      end

      def test_truncate_does_not_close_an_already_closed_hyperlink
        input = "\x1b]8;;u\x1b\\a\x1b]8;;\x1b\\bcdef"
        assert_example(3, input, "\x1b]8;;u\x1b\\a\x1b]8;;\x1b\\b" + Truncater::TRUNCATED)
      end

      def test_truncate_preserves_non_utf_8_encodings
        binary = "\xc3\xa9abcdef".b
        binary_result = Truncater.call(binary, 4)
        assert_equal("\xc3\xa9a\e[0m?".b, binary_result)
        assert_equal(Encoding::ASCII_8BIT, binary_result.encoding)

        latin1 = 'éabcdef'.encode(Encoding::ISO_8859_1)
        latin1_result = Truncater.call(latin1, 4)
        assert_equal("éab\e[0m?".encode(Encoding::ISO_8859_1), latin1_result)
        assert_equal(Encoding::ISO_8859_1, latin1_result.encoding)

        windows_1252 = 'éabcdef'.encode(Encoding::Windows_1252)
        windows_1252_result = Truncater.call(windows_1252, 4)
        assert_equal("éab\e[0m…".encode(Encoding::Windows_1252), windows_1252_result)
        assert_equal(Encoding::Windows_1252, windows_1252_result.encoding)
      end

      def test_truncate_invariants
        rng = Random.new(20260812)
        fragments = [
          'plain',
          ' ',
          "\n",
          '漢字',
          '🔧',
          "e\u0301",
          "\e[31m",
          "\e[0m",
          "\e[?25l",
          "\e[K",
          "\e]8;;https://example.com\e\\",
          ANSI::HYPERLINK_END,
        ]

        250.times do
          input = Array.new(rng.rand(1..20)) { fragments.sample(random: rng) }.join
          (1..12).each do |width|
            result = Truncater.call(input, width)

            assert_operator(ANSI.printing_width(result), :<=, width)
            next if result == input

            ANSI.each_token(result) do |kind, token|
              next unless kind == :sequence

              complete = ANSI::CSI_SEQUENCE.match?(token) || ANSI::OSC_SEQUENCE.match?(token)
              assert(complete, "truncation left an incomplete sequence: #{token.inspect}")
            end
          end
        end
      end

      private

      def assert_example(width, from, to)
        truncated = CLI::UI::Truncater.call(from, width)
        assert_equal(to.codepoints.map { |c| c.to_s(16) }, truncated.codepoints.map { |c| c.to_s(16) })
      end
    end
  end
end
