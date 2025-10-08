# typed: true
# frozen_string_literal: true

module CLI
  module UI
    module Frame
      module FrameStack
        class StackItem
          #: CLI::UI::Color
          attr_reader :color

          #: CLI::UI::Frame::FrameStyle
          attr_reader :frame_style

          #: (CLI::UI::colorable color_name, frame_stylable style_name) -> void
          def initialize(color_name, style_name)
            @color = CLI::UI.resolve_color(color_name)
            @frame_style = CLI::UI.resolve_style(style_name)
          end
        end

        class << self
          # Fetch all items off the frame stack
          #: -> Array[StackItem]
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
          #: (?StackItem? item, ?color: CLI::UI::Color?, ?style: CLI::UI::Frame::FrameStyle?) -> void
          def push(item = nil, color: nil, style: nil)
            if color.nil? != style.nil? || item.nil? == color.nil?
              raise ArgumentError, 'Must give one of item or color: and style:'
            end

            c = color #: as !nil
            s = style #: as !nil
            items.push(item || StackItem.new(c, s))
          end

          # Removes and returns the last stack item off the stack
          #: -> StackItem?
          def pop
            items.pop
          end
        end
      end
    end
  end
end
