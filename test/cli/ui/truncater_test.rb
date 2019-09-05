require 'test_helper'

module CLI
  module UI
    class TruncaterTest < MiniTest::Test
      MAN     = "\u{1f468}" # width=2
      COOKING = "\u{1f373}" # width=2
      ZWJ     = "\u{200d}"  # width=complicated

      MAN_COOKING = MAN + ZWJ + COOKING # width=2

      def test_truncate
        assert_example(3, "foobar", "fo\x1b[0m…")
        assert_example(5, "foobar", "foob\x1b[0m…")
        assert_example(6, "foobar", "foobar")
        assert_example(6, "foo\x1b[31mbar\x1b[0m", "foo\x1b[31mbar\x1b[0m")
        assert_example(6, "\x1b[31mfoobar", "\x1b[31mfoobar")
        assert_example(3, MAN_COOKING + MAN_COOKING, MAN_COOKING + Truncater::TRUNCATED)
        assert_example(3, "A" + MAN_COOKING, "A" + MAN_COOKING)
        assert_example(3, "AB" + MAN_COOKING, "AB" + Truncater::TRUNCATED)
      end

      private

      def assert_example(width, from, to)
        truncated = CLI::UI::Truncater.call(from, width)
        assert_equal(to.codepoints.map { |c| c.to_s(16) }, truncated.codepoints.map { |c| c.to_s(16) })
      end
    end
  end
end
