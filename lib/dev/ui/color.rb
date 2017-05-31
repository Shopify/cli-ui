require 'dev/ui'

module Dev
  module UI
    class Color
      attr_reader :sgr, :name, :code
      def initialize(sgr, name)
        @sgr  = sgr
        @code = Dev::UI::ANSI.sgr(sgr)
        @name = name
      end

      RED     = new('31', :red)
      GREEN   = new('32', :green)
      YELLOW  = new('33', :yellow)
      # default blue is low-contrast against black in some default terminal color scheme
      BLUE    = new('94', :blue) # 9x = high-intensity fg color x
      MAGENTA = new('35', :magenta)
      CYAN    = new('36', :cyan)
      RESET   = new('0',  :reset)
      BOLD    = new('1',  :bold)
      WHITE   = new('97', :white)

      MAP = {
        red:     RED,
        green:   GREEN,
        yellow:  YELLOW,
        blue:    BLUE,
        magenta: MAGENTA,
        cyan:    CYAN,
        reset:   RESET,
        bold:    BOLD,
      }.freeze

      class InvalidColorName < ArgumentError
        def initialize(name)
          @name = name
        end

        def message
          keys = Color.available.map(&:inspect).join(',')
          "invalid color: #{@name.inspect} " \
            "-- must be one of Dev::UI::Color.available (#{keys})"
        end
      end

      def self.lookup(name)
        MAP.fetch(name)
      rescue KeyError
        raise InvalidColorName, name
      end

      def self.available
        MAP.keys
      end
    end
  end
end
