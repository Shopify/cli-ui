require 'cli/ui/frame'

module CLI
  module UI
    module Frame
      module FrameStyle
        class << self
          @@loaded_styles = []

          def loaded_styles
            @@loaded_styles.map(&:to_s)
          end

          def lookup(input)
            @@loaded_styles.find { |style| style.to_s == input.to_s }
          end

          def extended(base)
            @@loaded_styles << base
            base.extend(Interface)
          end
        end

        private

        # Public interface for FrameStyles
        # Applied by extending FrameStyle
        module Interface
          def to_s
            raise NotImplementedError
          end

          def name
            to_s
          end

          def prefix
            raise NotImplementedError
          end

          # Opens a new frame. Can be nested
          # Can be invoked in two ways: block and blockless
          # * In block form, the frame is closed automatically when the block returns
          # * In blockless form, caller MUST call +Frame.close+ when the frame is logically done
          # * Blockless form is strongly discouraged in cases where block form can be made to work
          #
          # https://user-images.githubusercontent.com/3074765/33799861-cb5dcb5c-dd01-11e7-977e-6fad38cee08c.png
          #
          # The return value of the block determines if the block is a "success" or a "failure"
          #
          # ==== Attributes
          #
          # * +text+ - (required) the text/title to output in the frame
          #
          # ==== Options
          #
          # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
          # * +:failure_text+ - If the block failed, what do we output? Defaults to nil
          # * +:success_text+ - If the block succeeds, what do we output? Defaults to nil
          # * +:timing+ - How long did the frame content take? Invalid for blockless. Defaults to true for the block form
          # * +frame_style+ - The frame style to use for this frame
          #
          # ==== Example
          #
          # ===== Block Form (Assumes +CLI::UI::StdoutRouter.enable+ has been called)
          #
          #   CLI::UI::Frame.open('Open') { puts 'hi' }
          #
          # Output:
          #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #   ┃ hi
          #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (0.0s) ━━
          #
          # ===== Blockless Form
          #
          #   CLI::UI::Frame.open('Open')
          #
          # Output:
          #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #
          #
          def open(text, color: nil)
            raise NotImplementedError
          end

          # Closes a frame
          # Automatically called for a block-form +open+
          #
          # ==== Attributes
          #
          # * +text+ - (required) the text/title to output in the frame
          #
          # ==== Options
          #
          # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
          # * +:elapsed+ - How long did the frame take? Defaults to nil
          # * +frame_style+ - The frame style to use for this frame
          #
          # ==== Example
          #
          #   CLI::UI::Frame.close('Close')
          #
          # Output:
          #   ┗━━ Close ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #
          def close(text, color: nil, elapsed: nil)
            raise NotImplementedError
          end

          # Adds a divider in a frame
          # Used to separate information within a single frame
          #
          # ==== Attributes
          #
          # * +text+ - (required) the text/title to output in the frame
          #
          # ==== Options
          #
          # * +:color+ - The color of the frame. Defaults to +DEFAULT_FRAME_COLOR+
          # * +frame_style+ - The frame style to use for this frame
          #
          # ==== Example
          #
          #   CLI::UI::Frame.open('Open') { CLI::UI::Frame.divider('Divider') }
          #
          # Output:
          #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #   ┣━━ Divider ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          #
          # ==== Raises
          #
          # MUST be inside an open frame or it raises a +UnnestedFrameException+
          #
          def divider(text, color: nil)
            raise NotImplementedError
          end

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
