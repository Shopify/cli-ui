require 'test_helper'

module Dev
  class UITest < MiniTest::Test
    def test_resolve_test
      input = "a{{blue:b {{*}}{{bold:c {{red:d}}}}{{bold: e}}}} f"
      expected = "\e[0ma\e[0;34mb \e[0;33m⭑\e[0;34;1mc \e[0;34;1;31md\e[0;34;1m e\e[0m f"
      actual = Dev::UI.resolve_text(input)
      assert_equal(expected, actual)
    end
  end
end
