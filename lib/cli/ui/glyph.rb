require 'cli/ui'

module CLI
  module UI
    class Glyph
      class InvalidGlyphHandle < ArgumentError
        def initialize(handle)
          @handle = handle
        end

        def message
          keys = Glyph.available.join(',')
          "invalid glyph handle: #{@handle} " \
            "-- must be one of CLI::UI::Glyph.available (#{keys})"
        end
      end

      attr_reader :handle, :codepoint, :color, :char, :to_s, :fmt

      # Creates a new glyph
      #
      # ==== Attributes
      #
      # * +handle+ - The handle in the +MAP+ constant
      # * +codepoint+ - The codepoint used to create the glyph (e.g. +0x2717+ for a ballot X)
      # * +color+ - What color to output the glyph. Check +CLI::UI::Color+ for options.
      #
      def initialize(handle, codepoint, color)
        @handle    = handle
        @codepoint = codepoint
        @color     = color
        @char      = Array(codepoint).pack('U*')
        @to_s      = color.code + char + Color::RESET.code
        @fmt       = "{{#{color.name}:#{char}}}"

        MAP[handle] = self
      end

      # Mapping of glyphs to terminal output
      MAP = {}
      STAR      = new('*', 0x2b51,           Color::YELLOW) # YELLOW SMALL STAR (⭑)
      INFO      = new('i', 0x1d4be,          Color::BLUE)   # BLUE MATHEMATICAL SCRIPT SMALL i (𝒾)
      QUESTION  = new('?', 0x003f,           Color::BLUE)   # BLUE QUESTION MARK (?)
      CHECK     = new('v', 0x2713,           Color::GREEN)  # GREEN CHECK MARK (✓)
      X         = new('x', 0x2717,           Color::RED)    # RED BALLOT X (✗)
      BUG       = new('b', 0x1f41b,          Color::WHITE)  # Bug emoji (🐛)
      CHEVRON   = new('>', 0xbb,             Color::YELLOW) # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK (»)
      HOURGLASS = new('H', [0x231b, 0xfe0e], Color::BLUE)   # HOURGLASS + VARIATION SELECTOR 15 (⌛︎)

      # Looks up a glyph by name
      #
      # ==== Raises
      # Raises a InvalidGlyphHandle if the glyph is not available
      # You likely need to create it with +.new+ or you made a typo
      #
      # ==== Returns
      # Returns a terminal output-capable string
      #
      def self.lookup(name)
        MAP.fetch(name.to_s)
      rescue KeyError
        raise InvalidGlyphHandle, name
      end

      # All available glyphs by name
      #
      def self.available
        MAP.keys
      end
    end
  end
end
