# coding: utf-8

# typed: true

require 'cli/ui'
require 'cli/ui/frame/frame_stack'
require 'cli/ui/frame/frame_style'

module CLI
  module UI
    module Frame
      class UnnestedFrameException < StandardError; end
      DEFAULT_FRAME_COLOR = CLI::UI.resolve_color(:cyan)

      class << self
        extend T::Sig

        sig { returns(FrameStyle) }
        def frame_style
          @frame_style ||= FrameStyle::Box
        end

        # Set the default frame style.
        #
        # Raises ArgumentError if +frame_style+ is not valid
        #
        # ==== Attributes
        #
        # * +symbol+ or +FrameStyle+ - the default frame style to use for frames
        #
        sig { params(frame_style: FrameStylable).void }
        def frame_style=(frame_style)
          @frame_style = CLI::UI.resolve_style(frame_style)
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
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout.
        #
        # ==== Example
        #
        # ===== Block Form (Assumes +CLI::UI::StdoutRouter.enable+ has been called)
        #
        #   CLI::UI::Frame.open('Open') { puts 'hi' }
        #
        # Default Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┃ hi
        #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (0.0s) ━━
        #
        # ===== Blockless Form
        #
        #   CLI::UI::Frame.open('Open')
        #
        # Default Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        #
        sig do
          type_parameters(:T).params(
            text: String,
            color: Colorable,
            failure_text: T.nilable(String),
            success_text: T.nilable(String),
            timing: T.any(T::Boolean, Numeric),
            frame_style: FrameStylable,
            to: IOLike,
            block: T.nilable(T.proc.returns(T.type_parameter(:T))),
          ).returns(T.nilable(T.type_parameter(:T)))
        end
        def open(
          text,
          color: DEFAULT_FRAME_COLOR,
          failure_text: nil,
          success_text: nil,
          timing: block_given?,
          frame_style: self.frame_style,
          to: $stdout,
          &block
        )
          frame_style = CLI::UI.resolve_style(frame_style)
          color = CLI::UI.resolve_color(color)

          unless block_given?
            if failure_text
              raise ArgumentError, 'failure_text is not compatible with blockless invocation'
            elsif success_text
              raise ArgumentError, 'success_text is not compatible with blockless invocation'
            elsif timing
              raise ArgumentError, 'timing is not compatible with blockless invocation'
            end
          end

          t_start = Time.now
          CLI::UI.raw do
            to.print(prefix.chop)
            to.puts(frame_style.start(text, color: color))
          end
          FrameStack.push(color: color, style: frame_style)

          return unless block_given?

          closed = false
          begin
            success = false
            success = yield
          rescue
            closed = true
            t_diff = elapsed(t_start, timing)
            close(failure_text, color: :red, elapsed: t_diff, to: to)
            raise
          else
            success
          ensure
            unless closed
              t_diff = elapsed(t_start, timing)
              if T.unsafe(success) != false
                close(success_text, color: color, elapsed: t_diff, to: to)
              else
                close(failure_text, color: :red, elapsed: t_diff, to: to)
              end
            end
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
        # * +frame_style+ - The frame style to use for this frame
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout.
        #
        # ==== Example
        #
        #   CLI::UI::Frame.open('Open') { CLI::UI::Frame.divider('Divider') }
        #
        # Default Output:
        #   ┏━━ Open ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┣━━ Divider ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        # ==== Raises
        #
        # MUST be inside an open frame or it raises a +UnnestedFrameException+
        #
        sig do
          params(
            text: T.nilable(String),
            color: T.nilable(Colorable),
            frame_style: T.nilable(FrameStylable),
            to: IOLike,
          ).void
        end
        def divider(text, color: nil, frame_style: nil, to: $stdout)
          fs_item = FrameStack.pop
          raise UnnestedFrameException, 'No frame nesting to unnest' unless fs_item

          divider_color = CLI::UI.resolve_color(color || fs_item.color)
          frame_style = CLI::UI.resolve_style(frame_style || fs_item.frame_style)

          CLI::UI.raw do
            to.print(prefix.chop)
            to.puts(frame_style.divider(text.to_s, color: divider_color))
          end

          FrameStack.push(fs_item)
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
        # * +:color+ - The color of the frame. Defaults to nil
        # * +:elapsed+ - How long did the frame take? Defaults to nil
        # * +frame_style+ - The frame style to use for this frame.  Defaults to nil
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout.
        #
        # ==== Example
        #
        #   CLI::UI::Frame.close('Close')
        #
        # Default Output:
        #   ┗━━ Close ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        # ==== Raises
        #
        # MUST be inside an open frame or it raises a +UnnestedFrameException+
        #
        sig do
          params(
            text: T.nilable(String),
            color: T.nilable(Colorable),
            elapsed: T.nilable(Numeric),
            frame_style: T.nilable(FrameStylable),
            to: IOLike,
          ).void
        end
        def close(text, color: nil, elapsed: nil, frame_style: nil, to: $stdout)
          fs_item = FrameStack.pop
          raise UnnestedFrameException, 'No frame nesting to unnest' unless fs_item

          close_color = CLI::UI.resolve_color(color || fs_item.color)
          frame_style = CLI::UI.resolve_style(frame_style || fs_item.frame_style)
          elapsed_string = elapsed ? "(#{elapsed.round(2)}s)" : nil

          CLI::UI.raw do
            to.print(prefix.chop)
            to.puts(frame_style.close(text.to_s, color: close_color, right_text: elapsed_string))
          end
        end

        # Determines the prefix of a frame entry taking multi-nested frames into account
        #
        # ==== Options
        #
        # * +:color+ - The color of the prefix. Defaults to +Thread.current[:cliui_frame_color_override]+
        #
        sig { params(color: T.nilable(Colorable)).returns(String) }
        def prefix(color: Thread.current[:cliui_frame_color_override])
          +''.tap do |output|
            items = FrameStack.items

            items[0..-2].to_a.each do |item|
              output << item.color.code if CLI::UI.enable_color?
              output << item.frame_style.prefix
              output << CLI::UI::Color::RESET.code if CLI::UI.enable_color?
            end

            if (item = items.last)
              final_color = color || item.color
              output << CLI::UI.resolve_color(final_color).code if CLI::UI.enable_color?
              output << item.frame_style.prefix
              output << CLI::UI::Color::RESET.code if CLI::UI.enable_color?
              output << ' '
            end
          end
        end

        # The width of a prefix given the number of Frames in the stack
        sig { returns(Integer) }
        def prefix_width
          w = FrameStack.items.reduce(0) do |width, item|
            width + item.frame_style.prefix_width
          end

          w.zero? ? w : w + 1
        end

        # Override a color for a given thread.
        #
        # ==== Attributes
        #
        # * +color+ - The color to override to
        #
        sig do
          type_parameters(:T)
            .params(color: Colorable, block: T.proc.returns(T.type_parameter(:T)))
            .returns(T.type_parameter(:T))
        end
        def with_frame_color_override(color, &block)
          prev = Thread.current[:cliui_frame_color_override]
          Thread.current[:cliui_frame_color_override] = color
          yield
        ensure
          Thread.current[:cliui_frame_color_override] = prev
        end

        private

        # If timing is:
        #   Numeric: return it
        #   false: return nil
        #   true: defaults to Time.new
        sig { params(start: Time, timing: T.any(Numeric, T::Boolean)).returns(T.nilable(Numeric)) }
        def elapsed(start, timing)
          return timing if timing.is_a?(Numeric)
          return if timing.is_a?(FalseClass)

          timing = Time.new
          timing - start
        end
      end
    end
  end
end
