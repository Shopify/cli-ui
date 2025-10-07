# typed: true
# frozen_string_literal: true

require 'cli/ui'

module CLI
  module UI
    class Glyph
      class InvalidGlyphHandle < ArgumentError
        #: (String handle) -> void
        def initialize(handle)
          super
          @handle = handle
        end

        #: -> String
        def message
          keys = Glyph.available.join(',')
          "invalid glyph handle: #{@handle} " \
            "-- must be one of CLI::UI::Glyph.available (#{keys})"
        end
      end

      #: String
      attr_reader :handle, :to_s, :fmt, :char

      #: (Integer | Array[Integer])
      attr_reader :codepoint

      #: Color
      attr_reader :color

      # Creates a new glyph
      #
      # ==== Attributes
      #
      # * +handle+ - The handle in the +MAP+ constant
      # * +codepoint+ - The codepoint used to create the glyph (e.g. +0x2717+ for a ballot X)
      # * +plain+ - A fallback plain string to be used in case glyphs are disabled
      # * +color+ - What color to output the glyph. Check +CLI::UI::Color+ for options.
      #
      #: (String handle, (Integer | Array[Integer]) codepoint, String plain, Color color) -> void
      def initialize(handle, codepoint, plain, color)
        @handle    = handle
        @codepoint = codepoint
        @color     = color
        @char      = CLI::UI::OS.current.use_emoji? ? Array(codepoint).pack('U*') : plain
        @to_s      = color.code + @char + Color::RESET.code
        @fmt       = "{{#{color.name}:#{@char}}}"

        MAP[handle] = self
      end

      # Mapping of glyphs to terminal output
      MAP = {}
      STAR      = new('*', 0x2b51,           '*', Color::YELLOW) # YELLOW SMALL STAR (⭑)
      INFO      = new('i', 0x1d4be,          'i', Color::BLUE)   # BLUE MATHEMATICAL SCRIPT SMALL i (𝒾)
      QUESTION  = new('?', 0x003f,           '?', Color::BLUE)   # BLUE QUESTION MARK (?)
      CHECK     = new('v', 0x2713,           '√', Color::GREEN)  # GREEN CHECK MARK (✓)
      X         = new('x', 0x2717,           'X', Color::RED)    # RED BALLOT X (✗)
      BUG       = new('b', 0x1f41b,          '!', Color::WHITE)  # Bug emoji (🐛)
      CHEVRON   = new('>', 0xbb,             '»', Color::YELLOW) # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK (»)
      HOURGLASS = new('H', 0x29d6,           'H', Color::ORANGE) # HOURGLASS (⧖)
      WARNING   = new('!', [0x26a0, 0xfe0f], '!', Color::YELLOW) # WARNING SIGN + VARIATION SELECTOR 16 (⚠️ )

      class << self
        # Looks up a glyph by name
        #
        # ==== Raises
        # Raises a InvalidGlyphHandle if the glyph is not available
        # You likely need to create it with +.new+ or you made a typo
        #
        # ==== Returns
        # Returns a terminal output-capable string
        #
        #: (String name) -> Glyph
        def lookup(name)
          MAP.fetch(name.to_s)
        rescue KeyError
          raise InvalidGlyphHandle, name
        end

        # All available glyphs by name
        #
        #: -> Array[String]
        def available
          MAP.keys
        end
      end
    end
  end
end
