require 'cli/ui/frame'

module CLI
  module UI
    module Frame
      module FrameStyle
        class << self
          @loaded_styles = []

          def loaded_styles
            @loaded_styles.map(&:to_s)
          end

          def lookup(input)
            @loaded_styles.find { |style| style.name.to_sym == input }
          end

          def extended(base)
            @loaded_styles << base
            base.extend(Interface)
          end
        end

        # Public interface for FrameStyles
        # Applied by extending FrameStyle
        module Interface
          def to_s
            raise NotImplementedError
          end

          def name
            to_s
          end

          # Returns the character(s) that should be printed at the beginning
          # of lines inside this frame
          def prefix
            raise NotImplementedError
          end

          # Returns the printing width of the prefix
          def prefix_width
            CLI::UI::ANSI.printing_width(prefix)
          end

          # rubocop:disable Lint/UnusedMethodArgument

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
          def open(text, color:)
            raise NotImplementedError
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
          def close(text, color:, right_text: nil)
            raise NotImplementedError
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
          def divider(text, color: nil)
            raise NotImplementedError
          end

          # rubocop:enable Lint/UnusedMethodArgument

          private

          def print_at_x(x, str)
            CLI::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
          end
        end
      end
    end
  end
end

require 'cli/ui/frame/frame_style/box'
require 'cli/ui/frame/frame_style/bracket'
