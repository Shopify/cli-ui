require('test_helper')

module CLI
  module UI
    module Widgets
      class StatusTest < MiniTest::Test
        def setup
          Spinner.index = 0
        end

        CASES = {
          "1:2:3:4" =>
            "\e[0m\e[1m[\e[0m\e[32m1✓ \e[31m2✗ \e[94m3%s \e[97m4\u231b\ufe0e\e[0m\e[1m]\e[0m",
          "0:0:0:0" =>
            "\e[0m\e[1m[\e[0m\e[38;5;244m0✓ \e[38;5;244m0✗ \e[38;5;244m0%s \e[38;5;244m0\u231b\ufe0e\e[0m\e[1m]\e[0m",
        }

        def test_status_widget
          assert_equal(
            format(CASES["1:2:3:4"], '⠋'),
            Widgets::Status.call("1:2:3:4"),
          )

          assert_equal(
            format(CASES["0:0:0:0"], '⠼'),
            Widgets::Status.call("0:0:0:0"),
          )

          Spinner.index = 1

          assert_equal(
            format(CASES["0:0:0:0"], '⠼'),
            Widgets::Status.call("0:0:0:0"),
          )

          assert_equal(
            format(CASES["1:2:3:4"], '⠙'),
            Widgets::Status.call("1:2:3:4"),
          )
        end
      end
    end
  end
end
