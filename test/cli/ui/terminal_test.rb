require 'test_helper'

module CLI
  module UI
    class TerminalTest < MiniTest::Test
      def test_width
        skip('flaky')

        obj = Object.new
        class << obj
          def winsize
            [10, 70]
          end
        end

        IO.expects(:respond_to?).with(:console).twice.returns(true)

        IO.expects(:console).returns(obj)
        assert_equal(70, Terminal.width)

        IO.expects(:console).returns(nil)
        assert_equal(80, Terminal.width)
      end
    end
  end
end
