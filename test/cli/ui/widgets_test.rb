require('test_helper')

module CLI
  module UI
    class WidgetsTest < MiniTest::Test
      def test_widgets
        assert_equal(Widgets::Status, Widgets.lookup('status'))

        assert_raises(Widgets::InvalidWidgetHandle) do
          Widgets.lookup('nope')
        end
      end
    end
  end
end
