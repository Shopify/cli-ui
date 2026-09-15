# frozen_string_literal: true

require 'test_helper'

module CLI
  class UITest < Minitest::Test
    def test_resolve_test
      input = 'a{{blue:b {{*}}{{bold:c {{red:d}}}}{{bold: e}}}} f'
      expected = "\e[0ma\e[0;94mb \e[0;33m⭑\e[0;94;1mc \e[0;94;1;31md\e[0;94;1m e\e[0m f"
      actual = CLI::UI.resolve_text(input)
      assert_equal(expected, actual)
    end

    def test_color
      prev = CLI::UI.enable_color?

      CLI::UI.enable_color = true
      assert_equal("\e[0;31ma\e[0m", CLI::UI.fmt('{{red:a}}'))
      CLI::UI.enable_color = false
      assert_equal('a', CLI::UI.fmt('{{red:a}}'))
    ensure
      CLI::UI.enable_color = prev
    end

    def test_link_preserves_unicode_and_percent_encoded_urls
      url = 'https://example.com/日本語/é?q=%1B%5D8%3B%3B&x=1#anchor'

      assert_equal("\e]8;;#{url}\e\\label\e]8;;\e\\", CLI::UI.link(url, 'label', format: false))
    end

    def test_link_preserves_label_formatting
      label = CLI::UI.fmt('{{blue:{{underline:label}}}}')

      assert_equal("\e]8;;https://example.com\e\\#{label}\e]8;;\e\\", CLI::UI.link('https://example.com', 'label'))
    end

    def test_link_rejects_terminal_controls_in_urls
      controls = (0x00..0x1f).to_a + (0x7f..0x9f).to_a
      [Encoding::UTF_8, Encoding::ASCII_8BIT].each do |encoding|
        controls.each do |codepoint|
          url = "https://example.com/#{codepoint.chr(encoding)}suffix"
          [true, false].each do |format|
            error = assert_raises(ArgumentError) { CLI::UI.link(url, 'label', format: format) }

            assert_equal('URL must not contain terminal control characters', error.message)
          end
        end
      end
    end

    def test_link_rejects_urls_that_terminate_osc8_and_inject_commands
      [
        "\e\\\e]2;injected-title\a",
        "\a\e[2J",
        "\u009c\u009b2J",
        "\x9c\x9b2J".b,
      ].each do |payload|
        url = "https://example.com/private-token#{payload}"

        error = assert_raises(ArgumentError) { CLI::UI.link(url, 'label') }

        refute_includes(error.message, 'private-token')
      end
    end
  end
end
