require 'dev/ui'

module Dev
  module UI
    class Glyph
      MAP = {}

      attr_reader :handle, :codepoint, :color, :char, :to_s, :fmt
      def initialize(handle, codepoint, color)
        @handle    = handle
        @codepoint = codepoint
        @color     = color
        @char      = [codepoint].pack('U')
        @to_s      = color.code + char + Color::RESET.code
        @fmt       = "{{#{color.name}:#{char}}}"

        MAP[handle] = self
      end

      STAR     = new('*', 0x2b51,  Color::YELLOW) # BLACK SMALL STAR
      INFO     = new('i', 0x1d4be, Color::BLUE)   # MATHEMATICAL SCRIPT SMALL I
      QUESTION = new('?', 0x003f,  Color::BLUE)   # QUESTION MARK
      CHECK    = new('v', 0x2713,  Color::GREEN)  # CHECK MARK
      X        = new('x', 0x2717,  Color::RED)    # BALLOT X

      class InvalidGlyphHandle < ArgumentError
        def initialize(handle)
          @handle = handle
        end

        def message
          keys = Glyph.available.join(',')
          "invalid glyph handle: #{@handle} " \
            "-- must be one of Dev::UI::Glyph.available (#{keys})"
        end
      end

      def self.lookup(name)
        MAP.fetch(name.to_s)
      rescue KeyError
        raise InvalidGlyphHandle, name
      end

      def self.available
        MAP.keys
      end
    end
  end
end
