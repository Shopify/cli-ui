require 'dev/ui'

module Dev
  module UI
    module Frame
      class UnnestedFrameException < StandardError; end
      class << self
        DEFAULT_FRAME_COLOR = Dev::UI.resolve_color(:cyan)

        # Opens a new frame. Can be nested
        # Can be invoked in two ways: block and blockless
        # * In block form, the frame is closed automatically when the block returns
        # * In blockless form, caller MUST call +Frame.close+ when the frame is logically done
        # * Blockless form is strongly discouraged in cases where block form can be made to work
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
        #
        # ==== Example
        # 
        # ===== Block Form (Assumes +Dev::UI::StdoutRouter.enable+ has been called)
        #
        #   Dev::UI::Frame.open('Open') { puts 'hi' }
        #
        # Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┃ hi
        #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (0.0s) ━━
        # 
        # ===== Blockless Form
        #
        #   Dev::UI::Frame.open('Open')
        #
        # Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        # 
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
        #
        # ==== Example
        #
        #   Dev::UI::Frame.close('Close')
        #
        # Output:
        #   ┗━━ Close ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        # 
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
        #
        # ==== Example
        #
        #   Dev::UI::Frame.open('Open') { Dev::UI::Frame.divider('Divider') }
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
          fs_item = FrameStack.pop
          raise UnnestedFrameException, "no frame nesting to unnest" unless fs_item
          color = Dev::UI.resolve_color(color)
          item  = Dev::UI.resolve_color(fs_item)

          Dev::UI.raw do
            puts edge(text, color: (color || item), first: Dev::UI::Box::Heavy::DIV)
          end
          FrameStack.push(item)
        end

        # Determines the prefix of a frame entry taking multi-nested frames into account
        #
        # ==== Options
        #
        # * +:color+ - The color of the prefix. Defaults to +Thread.current[:devui_frame_color_override]+ or nil
        #
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

        # Override a color for a given thread. 
        #
        # ==== Attributes
        #
        # * +color+ - The color to override to
        #
        def with_frame_color_override(color)
          prev = Thread.current[:devui_frame_color_override]
          Thread.current[:devui_frame_color_override] = color
          yield
        ensure
          Thread.current[:devui_frame_color_override] = prev
        end

        # The width of a prefix given the number of Frames in the stack 
        #
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

          is_ci = ![0, '', nil].include?(ENV['CI'])

          # Jumping around the line can cause some unwanted flashes
          o << Dev::UI::ANSI.hide_cursor

          if is_ci
            # In CI, we can't use absolute horizontal positions because of timestamps.
            # So we move around the line by offset from this cursor position.
            o << Dev::UI::ANSI.cursor_save
          else
            # Outside of CI, we reset to column 1 so that things like ^C don't
            # cause output misformatting.
            o << "\r"
          end

          o << color.code
          o << Dev::UI::Box::Heavy::HORZ * termwidth # draw a full line
          o << print_at_x(prefix_start, prefix, is_ci)
          o << color.code
          o << print_at_x(suffix_start, suffix, is_ci)
          o << Dev::UI::Color::RESET.code
          o << Dev::UI::ANSI.show_cursor
          o << "\n"

          o
        end

        def print_at_x(x, str, is_ci)
          if is_ci
            Dev::UI::ANSI.cursor_restore + Dev::UI::ANSI.cursor_forward(x) + str
          else
            Dev::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
          end
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
