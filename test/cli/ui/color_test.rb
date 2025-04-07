# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class ColorTest < Minitest::Test
      def test_colors
        assert_equal("\x1b[31m", Color::RED.code)
        assert_equal("\x1b[32m", Color::GREEN.code)
        assert_equal("\x1b[33m", Color::YELLOW.code)
        assert_equal("\x1b[94m", Color::BLUE.code)
        assert_equal("\x1b[35m", Color::MAGENTA.code)
        assert_equal("\x1b[36m", Color::CYAN.code)
        assert_equal("\x1b[0m",  Color::RESET.code)
        assert_equal("\x1b[1m",  Color::BOLD.code)
        assert_equal("\x1b[97m", Color::WHITE.code)
        assert_equal("\x1b[38;5;214m", Color::ORANGE.code)

        assert_equal('36',  Color::CYAN.sgr)
        assert_equal(:bold, Color::BOLD.name)

        assert_equal(Color::BLUE, Color.lookup(:blue))
        assert_equal(Color::RESET, Color.lookup(:reset))
        assert_equal(Color::ORANGE, Color.lookup(:orange))

        assert_raises(Color::InvalidColorName) do
          Color.lookup(:foobar)
        end
      end

      def test_useful_exception
        e = begin
          Color.lookup(:foobar)
        rescue => e
          e
        end
        assert_match(/invalid color: :foobar/, e.message) # error
        assert_match(/Color\.available/, e.message) # where to find colors
        assert_match(/:green/, e.message) # list of valid colors
      end
    end
  end
end
