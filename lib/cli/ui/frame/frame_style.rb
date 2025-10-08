# typed: true
# frozen_string_literal: true

require 'cli/ui/frame'

module CLI
  module UI
    module Frame
      # @abstract
      module FrameStyle
        include Kernel

        autoload(:Box, 'cli/ui/frame/frame_style/box')
        autoload(:Bracket, 'cli/ui/frame/frame_style/bracket')

        MAP = {
          box: -> { FrameStyle::Box },
          bracket: -> { FrameStyle::Bracket },
        }

        class << self
          # Lookup a frame style via its name
          #
          # ==== Attributes
          #
          # * +symbol+ - frame style name to lookup
          #: ((String | Symbol) name) -> FrameStyle
          def lookup(name)
            MAP.fetch(name.to_sym).call
          rescue KeyError
            raise(InvalidFrameStyleName, name)
          end
        end

        # @abstract
        #: -> Symbol
        def style_name
          raise(NotImplementedError)
        end

        # Returns the character(s) that should be printed at the beginning
        # of lines inside this frame
        # @abstract
        #: -> String
        def prefix
          raise(NotImplementedError)
        end

        # Returns the printing width of the prefix
        #: -> Integer
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
        # @abstract
        #: (String, color: CLI::UI::Color) -> String
        def start(text, color:)
          raise(NotImplementedError)
        end

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
        # @abstract
        #: (String, color: CLI::UI::Color, ?right_text: String?) -> String
        def close(text, color:, right_text: nil)
          raise(NotImplementedError)
        end

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
        # @abstract
        #: (String, color: CLI::UI::Color) -> String
        def divider(text, color:)
          raise(NotImplementedError)
        end

        #: (Integer x, String str) -> String
        def print_at_x(x, str)
          CLI::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
        end

        class InvalidFrameStyleName < ArgumentError
          #: ((String | Symbol) name) -> void
          def initialize(name)
            super
            @name = name
          end

          #: -> String
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
