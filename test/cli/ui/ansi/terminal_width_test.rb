# frozen_string_literal: true

require 'digest'
require 'test_helper'
require 'cli/ui/ansi/terminal_width'

module CLI
  module UI
    module ANSI
      class TerminalWidthTest < Minitest::Test
        def test_generated_ranges_are_current_sorted_and_unchanged
          assert_equal('17.0.0', TerminalWidth::UNICODE_VERSION)
          TerminalWidth::WIDE_RANGES.each_cons(2) do |left, right|
            assert_operator(left.end, :<, right.begin)
          end

          width_data = File.read(File.expand_path('../../../../lib/cli/ui/ansi/width_data.rb', __dir__))
          expected = width_data[/^# Width ranges SHA-256: ([0-9a-f]{64})$/, 1]
          serialized = TerminalWidth::WIDE_RANGES.map do |range|
            format('0x%04X..0x%04X', range.begin, range.end)
          end.join("\n")

          assert_equal(expected, Digest::SHA256.hexdigest(serialized))
        end

        def test_grapheme_width_matches_terminal_columns
          assert_equal(0, TerminalWidth.grapheme_width("\n"))
          assert_equal(1, TerminalWidth.grapheme_width("e\u0301"))
          assert_equal(1, TerminalWidth.grapheme_width("\u{26a0}"))
          assert_equal(2, TerminalWidth.grapheme_width("\u{26a0}\u{fe0f}"))
          assert_equal(2, TerminalWidth.grapheme_width('漢'))
          assert_equal(2, TerminalWidth.grapheme_width('👩‍💻'))

          # U+1FA8A TROMBONE was added with Emoji 17.0.
          assert_equal(2, TerminalWidth.grapheme_width("\u{1fa8a}"))
        end
      end
    end
  end
end
