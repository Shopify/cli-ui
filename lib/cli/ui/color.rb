require 'cli/ui'

module CLI
  module UI
    class Color
      attr_reader :index, :name, :to_s

      # Creates a new color mapping
      #
      # The +index+ parameter can be 0 through 7, or 8
      # through 15 for bright colours, or whatever other
      # arguments +setaf+ can take.
      #
      # https://www.freebsd.org/cgi/man.cgi?query=terminfo&sektion=5
      #
      # ==== Attributes
      #
      # * +index+ - The color argument for terminfo
      # * +name+ - The name of the color
      #
      def initialize(index, name)
        @index = index
        @to_s = CLI::UI::Terminal.fg_color(index)
        @name = name
      end

      # default blue is low-contrast against black in some
      #   default terminal color scheme
      #
      # when we want white, it looks better bright, too.
      bright = 8

      BLACK    = new(0,          :black)
      RED      = new(1,          :red)
      GREEN    = new(2,          :green)
      YELLOW   = new(3,          :yellow)
      BLUE     = new(4 + bright, :blue)
      DIM_BLUE = new(4,          :dim_blue)
      MAGENTA  = new(5,          :magenta)
      CYAN     = new(6,          :cyan)
      WHITE    = new(7 + bright, :white)

      MAP = {
        black:   BLACK,
        red:     RED,
        green:   GREEN,
        yellow:  YELLOW,
        blue:    BLUE,
        magenta: MAGENTA,
        cyan:    CYAN,
        white:   WHITE,
      }.freeze

      class InvalidColorName < ArgumentError
        def initialize(name)
          @name = name
        end

        def message
          keys = Color.available.map(&:inspect).join(',')
          "invalid color: #{@name.inspect} " \
            "-- must be one of CLI::UI::Color.available (#{keys})"
        end
      end

      # Looks up a color code by name
      #
      # ==== Raises
      # Raises a InvalidColorName if the color is not available
      # You likely need to add it to the +MAP+ or you made a typo
      #
      # ==== Returns
      # Returns a color code
      #
      def self.lookup(name)
        MAP.fetch(name)
      rescue KeyError
        raise InvalidColorName, name
      end

      # All available colors by name
      #
      def self.available
        MAP.keys
      end
    end
  end
end
