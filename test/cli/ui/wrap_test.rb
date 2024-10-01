require 'test_helper'

module CLI
  module UI
    class WrapTest < Minitest::Test
      def test_wrap
        para = 'Voluptatem consequatur ipsum. Totam omnis corrupti. Dignissimos esse repudiandae.'
        w = Wrap.new(para)

        ex = w.wrap(20)

        Terminal.stubs(:width).returns(20)
        assert_equal(ex, w.wrap)
      end
    end
  end
end
