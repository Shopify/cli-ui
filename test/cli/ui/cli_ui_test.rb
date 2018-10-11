require 'test_helper'

module CLI
  class UITest < MiniTest::Test
    def test_resolve_test
      input = "a{{blue:b {{*}}{{bold:c {{red:d}}}}{{bold: e}}}} f"
      expected = "\e[0ma\e[0;94mb \e[0;33m⭑\e[0;94;1mc \e[0;94;1;31md\e[0;94;1m e\e[0m f"
      actual = CLI::UI.resolve_text(input)
      assert_equal(expected, actual)
    end

    def test_color
      prev = CLI::UI.enable_color?

      CLI::UI.enable_color = true
      assert_equal("\e[0;31ma\e[0m", CLI::UI.fmt("{{red:a}}"))
      CLI::UI.enable_color = false
      assert_equal("a", CLI::UI.fmt("{{red:a}}"))
    ensure
      CLI::UI.enable_color = prev
    end
  end
end
