# typed: true

module CLI
  module UI
    module Frame
      module FrameStack
        class StackItem
          extend T::Sig

          sig { returns(CLI::UI::Color) }
          attr_reader :color

          sig { returns(CLI::UI::Frame::FrameStyle) }
          attr_reader :frame_style

          sig do
            params(color_name: CLI::UI::Colorable, style_name: FrameStylable)
              .void
          end
          def initialize(color_name, style_name)
            @color = CLI::UI.resolve_color(color_name)
            @frame_style = CLI::UI.resolve_style(style_name)
          end
        end

        class << self
          extend T::Sig

          # Fetch all items off the frame stack
          sig { returns(T::Array[StackItem]) }
          def items
            Thread.current[:cliui_frame_stack] ||= []
          end

          # Push a new item onto the frame stack.
          #
          # Either an item or a :color/:style pair should be pushed onto the stack.
          #
          # ==== Attributes
          #
          # * +item+ a +StackItem+ to push onto the stack. Defaults to nil
          #
          # ==== Options
          #
          # * +:color+ the color of the new stack item. Defaults to nil
          # * +:style+ the style of the new stack item. Defaults to nil
          #
          # ==== Raises
          #
          # If both an item and a color/style pair are given, raises an +ArgumentError+
          # If the given item is not a +StackItem+, raises an +ArgumentError+
          #
          sig do
            params(
              item: T.nilable(StackItem),
              color: T.nilable(CLI::UI::Color),
              style: T.nilable(CLI::UI::Frame::FrameStyle),
            )
              .void
          end
          def push(item = nil, color: nil, style: nil)
            if color.nil? != style.nil? || item.nil? == color.nil?
              raise ArgumentError, 'Must give one of item or color: and style:'
            end

            items.push(item || StackItem.new(T.must(color), T.must(style)))
          end

          # Removes and returns the last stack item off the stack
          sig { returns(T.nilable(StackItem)) }
          def pop
            items.pop
          end
        end
      end
    end
  end
end
