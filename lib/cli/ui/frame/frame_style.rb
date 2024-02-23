# typed: true

require 'cli/ui/frame'

module CLI
  module UI
    module Frame
      module FrameStyle
        include Kernel
        extend T::Sig
        extend T::Helpers
        abstract!

        autoload(:Box, 'cli/ui/frame/frame_style/box')
        autoload(:Bracket, 'cli/ui/frame/frame_style/bracket')

        MAP = {
          box: -> { FrameStyle::Box },
          bracket: -> { FrameStyle::Bracket },
        }

        class << self
          extend T::Sig

          # Lookup a frame style via its name
          #
          # ==== Attributes
          #
          # * +symbol+ - frame style name to lookup
          sig { params(name: T.any(String, Symbol)).returns(FrameStyle) }
          def lookup(name)
            MAP.fetch(name.to_sym).call
          rescue KeyError
            raise(InvalidFrameStyleName, name)
          end
        end

        sig { abstract.returns(Symbol) }
        def style_name; end

        # Returns the character(s) that should be printed at the beginning
        # of lines inside this frame
        sig { abstract.returns(String) }
        def prefix; end

        # Returns the printing width of the prefix
        sig { returns(Integer) }
        def prefix_width
          CLI::UI::ANSI.printing_width(prefix)
        end

        # Draws the "Open" line for this frame style
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - (required) The color of the frame.
        #
        sig { abstract.params(text: String, color: CLI::UI::Color).returns(String) }
        def start(text, color:); end

        # Draws the "Close" line for this frame style
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - (required) The color of the frame.
        # * +:right_text+ - Text to print at the right of the line. Defaults to nil
        #
        sig { abstract.params(text: String, color: CLI::UI::Color, right_text: T.nilable(String)).returns(String) }
        def close(text, color:, right_text: nil); end

        # Draws a "divider" line for the current frame style
        #
        # ==== Attributes
        #
        # * +text+ - (required) the text/title to output in the frame
        #
        # ==== Options
        #
        # * +:color+ - (required) The color of the frame.
        #
        sig { abstract.params(text: String, color: CLI::UI::Color).returns(String) }
        def divider(text, color:); end

        sig { params(x: Integer, str: String).returns(String) }
        def print_at_x(x, str)
          CLI::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
        end

        class InvalidFrameStyleName < ArgumentError
          extend T::Sig

          sig { params(name: T.any(String, Symbol)).void }
          def initialize(name)
            super
            @name = name
          end

          sig { returns(String) }
          def message
            keys = FrameStyle::MAP.keys.map(&:inspect).join(', ')
            "invalid frame style: #{@name.inspect} " \
              '-- must be one of CLI::UI::Frame::FrameStyle::MAP ' \
              "(#{keys})"
          end
        end
      end
    end
  end
end
