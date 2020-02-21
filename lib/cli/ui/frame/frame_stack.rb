module CLI
  module UI
    module Frame
      module FrameStack
        COLOR_ENVVAR = 'CLI_FRAME_STACK'
        STYLE_ENVVAR = 'CLI_STYLE_STACK'

        StackItem = Struct.new(:color_name, :style_name) do
          def color
            @color ||= CLI::UI.resolve_color(color_name)
          end

          def frame_style
            @frame_style ||= CLI::UI.resolve_style(style_name)
          end
        end

        class << self
          def items
            colors = ENV.fetch(COLOR_ENVVAR, '').split(':').map(&:to_sym)
            styles = ENV.fetch(STYLE_ENVVAR, '').split(':').map(&:to_sym)

            colors.length.times.map do |i|
              StackItem.new(colors[i], styles[i])
            end
          end

          def push(item=nil, color: nil, style: nil)
            unless item.nil?
              unless item.is_a? StackItem
                raise ArgumentError, "item must be a StackItem"
              end

              unless color.nil? and style.nil?
                raise ArgumentError, "Must give one of item or color: and style:"
              end
            end

            item ||= StackItem.new(color.name, style.name)

            curr = items
            curr << item

            serialize(curr)
          end

          def pop
            curr = items
            ret = curr.pop

            serialize(curr)

            ret.nil? ? nil : ret
          end

          private

          def serialize(items)
            colors = []
            styles = []

            items.each do |item|
              colors << item.color_name
              styles << item.style_name
            end

            ENV[COLOR_ENVVAR] = colors.join(':')
            ENV[STYLE_ENVVAR] = styles.join(':')
          end
        end
      end
    end
  end
end
