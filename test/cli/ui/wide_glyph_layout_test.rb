# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    # Locks ANSI's width table into real layout: a wide glyph measured one
    # column short would shift every character after it in these strings.
    # Expectations are spelled out as exact output rather than measured
    # with printing_width, which is the very thing under test. Color and
    # cursor movement are disabled so layout arrives as plain text instead
    # of repaints.
    class WideGlyphLayoutTest < Minitest::Test
      def setup
        CLI::UI.enable_color = false
        CLI::UI.enable_cursor = false
        super
      end

      def teardown
        CLI::UI.enable_color = true
        CLI::UI.enable_cursor = true
        super
      end

      def test_frame_pads_an_emoji_title_like_a_plain_one
        Terminal.stubs(:width).returns(20)

        with_emoji = capture_io { Frame.open('🚀 go', timing: false) {} }.first.lines.first.chomp
        plain = capture_io { Frame.open('ab go', timing: false) {} }.first.lines.first.chomp

        assert_equal('┏━━ 🚀 go ━━━━━━━━━', with_emoji)
        # 🚀 spans two columns, like 'ab': the rules must line up.
        assert_equal('┏━━ ab go ━━━━━━━━━', plain)
      end

      def test_table_pads_emoji_cells_by_column
        rows = Table.capture_table([['✅ pass', 'ok'], ['status', 'ok']])

        assert_equal(['✅ pass ok', 'status  ok'], rows)
      end

      def test_spin_group_truncates_a_vs16_glyph_title_by_column
        Terminal.stubs(:width).returns(12)

        out, _ = capture_io do
          StdoutRouter.ensure_activated
          sg = Spinner::SpinGroup.new
          sg.add('⚠️ wide glyph title') { true }
          sg.wait
        end

        # ⚠️ (U+26A0 + VS16) takes two columns, so twelve fill at the g.
        assert_equal("✓ ⚠️ wide g\e[0m…", out.lines.last.chomp)
      end
    end
  end
end
