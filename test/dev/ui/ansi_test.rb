require 'test_helper'

module Dev
  module UI
    class ANSITest < MiniTest::Test
      def test_sgr
        assert_equal("\x1b[1;34m", ANSI.sgr('1;34'))
      end

      def test_printing_width
        assert_equal(4, ANSI.printing_width("\x1b[38;2;100;100;100mtest\x1b[0m"))
        assert_equal(0, ANSI.printing_width(""))
      end
    end
  end
end
