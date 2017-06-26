require 'dev/ui'

module Dev
  module UI
    module Frame
      class << self
        DEFAULT_FRAME_COLOR = Dev::UI.resolve_color(:cyan)

        # Can be invoked in two ways: block and blockless
        # In block form, the frame is closed automatically when the block returns
        # In blockless form, caller MUST call Frame.close when the frame is
        #   logically done.
        # blockless form is strongly discouraged in cases where block form can be
        #   made to work.
        def open(
          text,
          color: DEFAULT_FRAME_COLOR,
          failure_text: nil,
          success_text: nil,
          timing:       nil
        )
          color = Dev::UI.resolve_color(color)

          unless block_given?
            if failure_text
              raise ArgumentError, "failure_text is not compatible with blockless invocation"
            elsif success_text
              raise ArgumentError, "success_text is not compatible with blockless invocation"
            elsif !timing.nil?
              raise ArgumentError, "timing is not compatible with blockless invocation"
            end
          end

          timing = true if timing.nil?

          t_start = Time.now.to_f
          Dev::UI.raw do
            puts edge(text, color: color, first: Dev::UI::Box::Heavy::TL)
          end
          FrameStack.push(color)

          return unless block_given?

          closed = false
          begin
            success = false
            success = yield
          rescue Exception
            closed = true
            t_diff = timing ? (Time.now.to_f - t_start) : nil
            close(failure_text, color: :red, elapsed: t_diff)
            raise
          else
            success
          ensure
            unless closed
              t_diff = timing ? (Time.now.to_f - t_start) : nil
              if success != false
                close(success_text, color: color, elapsed: t_diff)
              else
                close(failure_text, color: :red, elapsed: t_diff)
              end
            end
          end
        end

        def close(text, color: DEFAULT_FRAME_COLOR, elapsed: nil)
          color = Dev::UI.resolve_color(color)

          FrameStack.pop
          kwargs = {}
          if elapsed
            kwargs[:right_text] = "(#{elapsed.round(2)}s)"
          end
          Dev::UI.raw do
            puts edge(text, color: color, first: Dev::UI::Box::Heavy::BL, **kwargs)
          end
        end

        def divider(text, color: nil)
          fs_item = FrameStack.pop
          raise "no frame nesting to unnest" unless fs_item
          color = Dev::UI.resolve_color(color)
          item  = Dev::UI.resolve_color(fs_item)

          Dev::UI.raw do
            puts edge(text, color: (color || item), first: Dev::UI::Box::Heavy::DIV)
          end
          FrameStack.push(item)
        end

        def prefix(color: nil)
          pfx = String.new
          items = FrameStack.items
          items[0..-2].each do |item|
            pfx << Dev::UI.resolve_color(item).code << Dev::UI::Box::Heavy::VERT
          end
          if item = items.last
            c = Thread.current[:devui_frame_color_override] || color || item
            pfx << Dev::UI.resolve_color(c).code \
              << Dev::UI::Box::Heavy::VERT << ' ' << Dev::UI::Color::RESET.code
          end
          pfx
        end

        def with_frame_color_override(color)
          prev = Thread.current[:devui_frame_color_override]
          Thread.current[:devui_frame_color_override] = color
          yield
        ensure
          Thread.current[:devui_frame_color_override] = prev
        end

        def prefix_width
          w = FrameStack.items.size
          w.zero? ? 0 : w + 1
        end

        private

        def edge(text, color: raise, first: raise, right_text: nil)
          color = Dev::UI.resolve_color(color)
          text  = Dev::UI.resolve_text("{{#{color.name}:#{text}}}")

          prefix = String.new
          FrameStack.items.each do |item|
            prefix << Dev::UI.resolve_color(item).code << Dev::UI::Box::Heavy::VERT
          end
          prefix << color.code << first << (Dev::UI::Box::Heavy::HORZ * 2)
          text ||= ''
          unless text.empty?
            prefix << ' ' << text << ' '
          end

          termwidth = Dev::UI::Terminal.width

          suffix = String.new
          if right_text
            suffix << ' ' << right_text << ' '
          end

          suffix_width = Dev::UI::ANSI.printing_width(suffix)
          suffix_end   = termwidth - 2
          suffix_start = suffix_end - suffix_width

          prefix_width = Dev::UI::ANSI.printing_width(prefix)
          prefix_start = 0
          prefix_end   = prefix_start + prefix_width

          if prefix_end > suffix_start
            suffix = ''
            # if prefix_end > termwidth
            # we *could* truncate it, but let's just let it overflow to the
            # next line and call it poor usage of this API.
          end

          o = String.new

          o << "\r" # reset to start of line in case there's trailing input (e.g. "^C")
          o << color.code
          o << Dev::UI::Box::Heavy::HORZ * termwidth # draw a full line
          o << Dev::UI::ANSI.cursor_horizontal_absolute(1 + prefix_start)
          o << prefix
          o << Dev::UI::ANSI.cursor_horizontal_absolute(1 + suffix_start)
          o << color.code << suffix
          o << Dev::UI::Color::RESET.code
          o << "\n"

          o
        end

        module FrameStack
          ENVVAR = 'DEV_FRAME_STACK'

          def self.items
            ENV.fetch(ENVVAR, '').split(':').map(&:to_sym)
          end

          def self.push(item)
            curr = items
            curr << item.name
            ENV[ENVVAR] = curr.join(':')
          end

          def self.pop
            curr = items
            ret = curr.pop
            ENV[ENVVAR] = curr.join(':')
            ret.nil? ? nil : ret.to_sym
          end
        end
      end
    end
  end
end
