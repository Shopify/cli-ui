require 'cli/ui'

module CLI
  module UI
    module Frame
      class UnnestedFrameException < StandardError; end

      module EdgeRendererComponents
        def with_hidden_cursor(o)
          # Jumping around the line can cause some unwanted flashes
          o << CLI::UI::ANSI.hide_cursor
          yield
        ensure
          o << CLI::UI::ANSI.show_cursor
        end

        def reset_cursor(o)
          # We can't do this in CI because of log-prefixed lines, but in user
          # terminals, it's nice to reset to column 1 to overwrite any dangling
          # ^C or the like.
          o << "\r"
        end

        def set_color(o, color)
          if CLI::UI.enable_color?
            o << color.code
          end
        end

        def print_at_x(x, str)
          CLI::UI::ANSI.cursor_horizontal_absolute(1 + x) + str
        end

        Text = Struct.new(:text, :width, :start_index, :end_index)

        def calculate_prefix(prefix)
          text        = prefix
          width       = CLI::UI::ANSI.printing_width(text)
          start_index = 0
          end_index   = start_index + width
          Text.new(prefix, width, start_index, end_index)
        end

        def calculate_suffix(suffix, termwidth, prefix)
          text = suffix
          width = CLI::UI::ANSI.printing_width(suffix)
          end_index = termwidth - 2
          start_index = end_index - width

          # If the prefix and suffix can't both fit, leave out the suffix
          # completely.
          if prefix.end_index > start_index
            text = ''
            width = 0
            start_index = end_index
          end

          Text.new(text, width, start_index, end_index)
        end

      end

      # Uses cursor save/restore to more accurately render edges to precise
      # widths, even when we have emoji that print at semi-variable widths.
      module MacOSTerminalEdgeRenderer
        extend EdgeRendererComponents

        def self.render(termwidth:, color:, prefix:, suffix:)
          prefix = calculate_prefix(prefix)
          suffix = calculate_suffix(suffix, termwidth, prefix)

          o = +''
          with_hidden_cursor(o) do
            reset_cursor(o)
            set_color(o, color)
            o << CLI::UI::Box::Heavy::HORZ * termwidth # draw a full line
            o << print_at_x(prefix.start_index, prefix.text)
            set_color(o, color)
            o << print_at_x(suffix.start_index, suffix.text)
            set_color(o, CLI::UI::Color::RESET)
          end
          o << "\n"
        end
      end

      # Doesn't use cursor save/restore or other semi-exotic ANSI escape
      # sequences, which aren't supported by all terminals.
      module BuildkiteEdgeRenderer
        extend EdgeRendererComponents

        def self.render(termwidth:, color:, prefix:, suffix:)
          prefix = calculate_prefix(prefix)
          suffix = calculate_suffix(suffix, termwidth, prefix)

          interstitial_width = termwidth - (2 + prefix.width + suffix.width)

          o = +''
          o << prefix.text

          set_color(o, color)
          o << CLI::UI::Box::Heavy::HORZ * interstitial_width

          o << suffix.text

          set_color(o, color)
          o << CLI::UI::Box::Heavy::HORZ * 2

          set_color(o, CLI::UI::Color::RESET)
          o << "\n"
        end
      end

      module PipeEdgeRenderer
        extend EdgeRendererComponents

        # color is unused but necessary for the interface.
        # rubocop:disable Lint/UnusedMethodArgument
        def self.render(termwidth:, color:, prefix:, suffix:)
          prefix = calculate_prefix(prefix)
          suffix = calculate_suffix(suffix, termwidth, prefix)

          interstitial_width = termwidth - (2 + prefix.width + suffix.width)

          o = +''
          o << prefix.text
          o << CLI::UI::Box::Heavy::HORZ * interstitial_width
          o << suffix.text
          o << CLI::UI::Box::Heavy::HORZ * 2
          o << "\n"
        end
      end

      class << self
        attr_accessor :edge_renderer
      end

      def self.default_edge_renderer
        if ENV.key?('BUILDKITE')
          BuildkiteEdgeRenderer
        elsif !$stdout.tty?
          PipeEdgeRenderer
        else
          MacOSTerminalEdgeRenderer
        end
      end

      self.edge_renderer = default_edge_renderer

      class << self
        DEFAULT_FRAME_COLOR = CLI::UI.resolve_color(:cyan)

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
        def open(
          text,
          color: DEFAULT_FRAME_COLOR,
          failure_text: nil,
          success_text: nil,
          timing:       nil
        )
          color = CLI::UI.resolve_color(color)

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
          CLI::UI.raw do
            puts edge(text, color: color, first: CLI::UI::Box::Heavy::TL)
          end
          FrameStack.push(color)

          return unless block_given?

          closed = false
          begin
            success = false
            success = yield
          rescue
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
        #   CLI::UI::Frame.close('Close')
        #
        # Output:
        #   ┗━━ Close ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        #
        #
        def close(text, color: DEFAULT_FRAME_COLOR, elapsed: nil)
          color = CLI::UI.resolve_color(color)

          FrameStack.pop
          kwargs = {}
          if elapsed
            kwargs[:right_text] = "(#{elapsed.round(2)}s)"
          end
          CLI::UI.raw do
            puts edge(text, color: color, first: CLI::UI::Box::Heavy::BL, **kwargs)
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
          fs_item = FrameStack.pop
          raise UnnestedFrameException, "no frame nesting to unnest" unless fs_item
          color = CLI::UI.resolve_color(color)
          item  = CLI::UI.resolve_color(fs_item)

          CLI::UI.raw do
            puts edge(text, color: (color || item), first: CLI::UI::Box::Heavy::DIV)
          end
          FrameStack.push(item)
        end

        # Determines the prefix of a frame entry taking multi-nested frames into account
        #
        # ==== Options
        #
        # * +:color+ - The color of the prefix. Defaults to +Thread.current[:cliui_frame_color_override]+ or nil
        #
        def prefix(color: nil)
          pfx = +''
          items = FrameStack.items
          items[0..-2].each do |item|
            pfx << if_color(CLI::UI.resolve_color(item).code) << CLI::UI::Box::Heavy::VERT
          end
          if item = items.last
            c = Thread.current[:cliui_frame_color_override] || color || item
            pfx << if_color(CLI::UI.resolve_color(c).code) \
              << CLI::UI::Box::Heavy::VERT << ' ' << if_color(CLI::UI::Color::RESET.code)
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
          prev = Thread.current[:cliui_frame_color_override]
          Thread.current[:cliui_frame_color_override] = color
          yield
        ensure
          Thread.current[:cliui_frame_color_override] = prev
        end

        # The width of a prefix given the number of Frames in the stack
        #
        def prefix_width
          w = FrameStack.items.size
          w.zero? ? 0 : w + 1
        end

        private

        def edge(text, color: raise, first: raise, right_text: nil)
          color = CLI::UI.resolve_color(color)
          text  = CLI::UI.resolve_text("{{#{color.name}:#{text}}}")

          prefix = +''
          FrameStack.items.each do |item|
            prefix << if_color(CLI::UI.resolve_color(item).code) << CLI::UI::Box::Heavy::VERT
          end
          prefix << if_color(color.code) << first << (CLI::UI::Box::Heavy::HORZ * 2)
          text ||= ''
          unless text.empty?
            prefix << ' ' << text << ' '
          end

          termwidth = CLI::UI::Terminal.width

          suffix = +''
          if right_text
            suffix << ' ' << right_text << ' '
          end

          edge_renderer.render(
            termwidth:    termwidth,
            color:        color,
            prefix:       prefix,
            suffix:       suffix,
          )
        end

        def if_color(text)
          if CLI::UI.enable_color?
            text
          else
            ''
          end
        end

        module FrameStack
          ENVVAR = 'CLI_FRAME_STACK'

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
