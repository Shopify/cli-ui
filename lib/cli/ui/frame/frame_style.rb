# typed: true
require 'cli/ui/frame'

module CLI
  module UI
    module Frame
      module FrameStyle
        class << self
          extend T::Sig

          # rubocop:disable Style/ClassVars
          @@loaded_styles = []

          sig { returns(T.untyped) }
          def loaded_styles
            @@loaded_styles.map(&:name)
          end

          # Lookup a frame style via its name
          #
          # ==== Attributes
          #
          # * +symbol+ - frame style name to lookup
          sig { params(name: T.untyped).returns(T.untyped) }
          def lookup(name)
            @@loaded_styles
              .find { |style| style.name.to_sym == name }
              .tap  { |style| raise InvalidFrameStyleName, name if style.nil? }
          end

          sig { params(base: T.untyped).returns(T.untyped) }
          def extended(base)
            @@loaded_styles << base
            base.extend(Interface)
          end
          # rubocop:enable Style/ClassVars
        end

        class InvalidFrameStyleName < ArgumentError
          extend T::Sig

          sig { params(name: T.untyped).void }
          def initialize(name)
            super
            @name = name
          end

          sig { returns(T.untyped) }
          def message
            keys = FrameStyle.loaded_styles.map(&:inspect).join(',')
            "invalid frame style: #{@name.inspect}" \
              ' -- must be one of CLI::UI::Frame::FrameStyle.loaded_styles ' \
              "(#{keys})"
          end
        end

        # Public interface for FrameStyles
        # Applied by extending FrameStyle
        module Interface
          extend T::Sig

          # Because these are interface methods, we want to be explicit about their signatures,
          # even if we don't use the arguments.

          sig { returns(T.untyped) }
          def name
            raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
          end

          # Returns the character(s) that should be printed at the beginning
          # of lines inside this frame
          sig { returns(T.untyped) }
          def prefix
            raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
          end

          # Returns the printing width of the prefix
          sig { returns(T.untyped) }
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
          sig { params(text: T.untyped, color: T.untyped).returns(T.untyped) }
          def open(text, color:)
            raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
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
          sig { params(text: T.untyped, color: T.untyped, right_text: T.untyped).returns(T.untyped) }
          def close(text, color:, right_text: nil)
            raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
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
          sig { params(text: T.untyped, color: T.untyped).returns(T.untyped) }
          def divider(text, color: nil)
            raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
          end

          private

          sig { params(x: T.untyped, str: T.untyped).returns(T.untyped) }
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
