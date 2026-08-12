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

      def test_truncate_preserves_osc8_hyperlinks
        # OSC 8 hyperlinks: ESC ] 8 ;; url ST text ESC ] 8 ;; ST
        # Truncater must ignore OSC payload width (ANSI.printing_width already does).
        link = CLI::UI.link(
          'https://github.com/Shopify/shopify/pull/12345',
          '#12345',
          format: false,
        )

        assert_equal(6, ANSI.printing_width(link))
        assert_example(20, link, link)
        assert_example(6, link, link)
      end

      def test_truncate_osc8_hyperlink_by_visible_width
        link = CLI::UI.link('https://example.com/very/long/url', 'hello world', format: false)
        opening = "\x1b]8;;https://example.com/very/long/url\x1b\\"

        assert_example(6, link, "#{opening}hello#{Truncater::TRUNCATED}")
      end

      def test_truncate_preserves_bel_terminated_osc
        # OSC sequences may also end with BEL (e.g. OSC 9 progress)
        progress = "\x1b]9;4;1\x07"
        text = "#{progress}hello world"

        assert_example(20, text, text)
        assert_example(6, text, "#{progress}hello#{Truncater::TRUNCATED}")
      end

      def test_truncate_formatted_hyperlink_issue_614
        # Exact issue #614 reproduction (default formatted link)
        url = 'https://github.com/Shopify/shopify/pull/12345'
        link = CLI::UI.link(url, '#12345')

        assert_equal(6, ANSI.printing_width(link))
        assert_example(20, link, link)
      end

      private

      def assert_example(width, from, to)
        truncated = CLI::UI::Truncater.call(from, width)
        assert_equal(to.codepoints.map { |c| c.to_s(16) }, truncated.codepoints.map { |c| c.to_s(16) })
      end
    end
  end
end
