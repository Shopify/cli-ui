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
        assert_equal("\x1b[38;5;244m", Color::GRAY.code)
        assert_equal("\x1b[38;5;214m", Color::ORANGE.code)

        assert_equal('36',  Color::CYAN.sgr)
        assert_equal(:bold, Color::BOLD.name)

        assert_raises(Color::InvalidColorName) do
          Color.lookup(:foobar)
        end
      end

      def test_all_colors_lookup
        Color.available.each do |color_name|
          # rubocop:disable Sorbet/ConstantsFromStrings
          color_constant = Color.const_get(color_name.to_s.upcase)
          # rubocop:enable Sorbet/ConstantsFromStrings
          lookup_result = Color.lookup(color_name)

          assert_equal(color_constant, lookup_result, "Color lookup failed for #{color_name}")
          assert_equal(color_name, lookup_result.name, "Color name mismatch for #{color_name}")
          assert_instance_of(Color, lookup_result, "Lookup result is not a Color instance for #{color_name}")
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
