# typed: true

unless defined?(T)
  require('cli/ui/sorbet_runtime_stub')
end

module CLI
  module UI
    extend T::Sig

    autoload :ANSI,      'cli/ui/ansi'
    autoload :Glyph,     'cli/ui/glyph'
    autoload :Color,     'cli/ui/color'
    autoload :Frame,     'cli/ui/frame'
    autoload :OS,        'cli/ui/os'
    autoload :Printer,   'cli/ui/printer'
    autoload :Progress,  'cli/ui/progress'
    autoload :Prompt,    'cli/ui/prompt'
    autoload :Terminal,  'cli/ui/terminal'
    autoload :Truncater, 'cli/ui/truncater'
    autoload :Formatter, 'cli/ui/formatter'
    autoload :Spinner,   'cli/ui/spinner'
    autoload :Widgets,   'cli/ui/widgets'
    autoload :Wrap,      'cli/ui/wrap'

    # Convenience accessor to +CLI::UI::Spinner::SpinGroup+
    SpinGroup = Spinner::SpinGroup

    Colorable = T.type_alias { T.any(Symbol, String, CLI::UI::Color) }
    FrameStylable = T.type_alias { T.any(Symbol, String, CLI::UI::Frame::FrameStyle) }
    IOLike = T.type_alias { T.any(IO, StringIO) }

    class << self
      extend T::Sig

      # Glyph resolution using +CLI::UI::Glyph.lookup+
      # Look at the method signature for +Glyph.lookup+ for more details
      #
      # ==== Attributes
      #
      # * +handle+ - handle of the glyph to resolve
      #
      sig { params(handle: String).returns(Glyph) }
      def glyph(handle)
        CLI::UI::Glyph.lookup(handle)
      end

      # Color resolution using +CLI::UI::Color.lookup+
      # Will lookup using +Color.lookup+ unless it's already a CLI::UI::Color (or nil)
      #
      # ==== Attributes
      #
      # * +input+ - color to resolve
      #
      sig { params(input: Colorable).returns(CLI::UI::Color) }
      def resolve_color(input)
        case input
        when CLI::UI::Color
          input
        else
          CLI::UI::Color.lookup(input)
        end
      end

      # Frame style resolution using +CLI::UI::Frame::FrameStyle.lookup+.
      # Will lookup using +FrameStyle.lookup+ unless it's already a CLI::UI::Frame::FrameStyle(or nil)
      #
      # ==== Attributes
      #
      # * +input+ - frame style to resolve
      sig { params(input: FrameStylable).returns(CLI::UI::Frame::FrameStyle) }
      def resolve_style(input)
        case input
        when CLI::UI::Frame::FrameStyle
          input
        else
          CLI::UI::Frame::FrameStyle.lookup(input.to_s)
        end
      end

      # Convenience Method for +CLI::UI::Prompt.confirm+
      #
      # ==== Attributes
      #
      # * +question+ - question to confirm
      #
      sig { params(question: String, default: T::Boolean).returns(T::Boolean) }
      def confirm(question, default: true)
        CLI::UI::Prompt.confirm(question, default: default)
      end

      # Convenience Method for +CLI::UI::Prompt.any_key+
      #
      # ==== Attributes
      #
      # * +prompt+ - prompt to present
      #
      sig { params(prompt: String).returns(T.nilable(String)) }
      def any_key(prompt = 'Press any key to continue')
        CLI::UI::Prompt.any_key(prompt)
      end

      # Convenience Method for +CLI::UI::Prompt.ask+
      sig do
        params(
          question: String,
          options: T.nilable(T::Array[String]),
          default: T.nilable(T.any(String, T::Array[String])),
          is_file: T::Boolean,
          allow_empty: T::Boolean,
          multiple: T::Boolean,
          filter_ui: T::Boolean,
          select_ui: T::Boolean,
          options_proc: T.nilable(T.proc.params(handler: Prompt::OptionsHandler).void),
        ).returns(T.any(String, T::Array[String]))
      end
      def ask(
        question,
        options: nil,
        default: nil,
        is_file: false,
        allow_empty: true,
        multiple: false,
        filter_ui: true,
        select_ui: true,
        &options_proc
      )
        CLI::UI::Prompt.ask(
          question,
          options: options,
          default: default,
          is_file: is_file,
          allow_empty: allow_empty,
          multiple: multiple,
          filter_ui: filter_ui,
          select_ui: select_ui,
          &options_proc
        )
      end

      # Convenience Method to resolve text using +CLI::UI::Formatter.format+
      # Check +CLI::UI::Formatter::SGR_MAP+ for available formatting options
      #
      # ==== Attributes
      #
      # * +input+ - input to format
      # * +truncate_to+ - number of characters to truncate the string to (or nil)
      # * +enable_color+ - should color be used? default to true unless output is redirected.
      #
      sig { params(input: String, truncate_to: T.nilable(Integer), enable_color: T::Boolean).returns(String) }
      def resolve_text(input, truncate_to: nil, enable_color: enable_color?)
        formatted = CLI::UI::Formatter.new(input).format(enable_color: enable_color)
        return formatted unless truncate_to

        CLI::UI::Truncater.call(formatted, truncate_to)
      end

      # Convenience Method to format text using +CLI::UI::Formatter.format+
      # Check +CLI::UI::Formatter::SGR_MAP+ for available formatting options
      #
      # https://user-images.githubusercontent.com/3074765/33799827-6d0721a2-dd01-11e7-9ab5-c3d455264afe.png
      # https://user-images.githubusercontent.com/3074765/33799847-9ec03fd0-dd01-11e7-93f7-5f5cc540e61e.png
      #
      # ==== Attributes
      #
      # * +input+ - input to format
      #
      # ==== Options
      #
      # * +enable_color+ - should color be used? default to true unless output is redirected.
      #
      sig { params(input: String, enable_color: T::Boolean).returns(String) }
      def fmt(input, enable_color: enable_color?)
        CLI::UI::Formatter.new(input).format(enable_color: enable_color)
      end

      sig { params(input: String).returns(String) }
      def wrap(input)
        CLI::UI::Wrap.new(input).wrap
      end

      # Convenience Method for +CLI::UI::Printer.puts+
      #
      # ==== Attributes
      #
      # * +msg+ - Message to print
      # * +kwargs+ - keyword arguments for +Printer.puts+
      #
      sig do
        params(
          msg: String,
          frame_color: T.nilable(Colorable),
          to: IOLike,
          encoding: Encoding,
          format: T::Boolean,
          graceful: T::Boolean,
          wrap: T::Boolean,
        ).void
      end
      def puts(
        msg,
        frame_color: nil,
        to: $stdout,
        encoding: Encoding::UTF_8,
        format: true,
        graceful: true,
        wrap: true
      )
        CLI::UI::Printer.puts(
          msg,
          frame_color: frame_color,
          to: to,
          encoding: encoding,
          format: format,
          graceful: graceful,
          wrap: wrap,
        )
      end

      # Convenience Method for +CLI::UI::Frame.open+
      #
      # ==== Attributes
      #
      # * +args+ - arguments for +Frame.open+
      # * +block+ - block for +Frame.open+
      #
      sig do
        type_parameters(:T).params(
          text: String,
          color: T.nilable(Colorable),
          failure_text: T.nilable(String),
          success_text: T.nilable(String),
          timing: T.any(T::Boolean, Numeric),
          frame_style: FrameStylable,
          block: T.nilable(T.proc.returns(T.type_parameter(:T))),
        ).returns(T.nilable(T.type_parameter(:T)))
      end
      def frame(
        text,
        color: Frame::DEFAULT_FRAME_COLOR,
        failure_text: nil,
        success_text: nil,
        timing: block_given?,
        frame_style: Frame.frame_style,
        &block
      )
        CLI::UI::Frame.open(
          text,
          color: color,
          failure_text: failure_text,
          success_text: success_text,
          timing: timing,
          frame_style: frame_style,
          &block
        )
      end

      # Convenience Method for +CLI::UI::Spinner.spin+
      #
      # ==== Attributes
      #
      # * +args+ - arguments for +Spinner.open+
      # * +block+ - block for +Spinner.open+
      #
      sig do
        params(title: String, auto_debrief: T::Boolean, block: T.proc.params(task: Spinner::SpinGroup::Task).void)
          .returns(T::Boolean)
      end
      def spinner(title, auto_debrief: true, &block)
        CLI::UI::Spinner.spin(title, auto_debrief: auto_debrief, &block)
      end

      # Convenience Method to override frame color using +CLI::UI::Frame.with_frame_color+
      #
      # ==== Attributes
      #
      # * +color+ - color to override to
      # * +block+ - block for +Frame.with_frame_color_override+
      #
      sig do
        type_parameters(:T)
          .params(color: Colorable, block: T.proc.returns(T.type_parameter(:T)))
          .returns(T.type_parameter(:T))
      end
      def with_frame_color(color, &block)
        CLI::UI::Frame.with_frame_color_override(color, &block)
      end

      # Duplicate output to a file path
      #
      # ==== Attributes
      #
      # * +path+ - path to duplicate output to
      #
      sig do
        type_parameters(:T)
          .params(path: String, block: T.proc.returns(T.type_parameter(:T)))
          .returns(T.type_parameter(:T))
      end
      def log_output_to(path, &block)
        if CLI::UI::StdoutRouter.duplicate_output_to
          raise 'multiple logs not allowed'
        end

        CLI::UI::StdoutRouter.duplicate_output_to = File.open(path, 'w')
        yield
      ensure
        if (file_descriptor = CLI::UI::StdoutRouter.duplicate_output_to)
          begin
            file_descriptor.close
          rescue IOError
            nil
          end
          CLI::UI::StdoutRouter.duplicate_output_to = nil
        end
      end

      # Disable all framing within a block
      #
      # ==== Attributes
      #
      # * +block+ - block in which to disable frames
      #
      sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
      def raw(&block)
        prev = Thread.current[:no_cliui_frame_inset]
        Thread.current[:no_cliui_frame_inset] = true
        yield
      ensure
        Thread.current[:no_cliui_frame_inset] = prev
      end

      # Check whether colour is enabled in Formatter, Frame, and Spinner output.
      # By default, colour is enabled when STDOUT is a TTY; that is, when output
      # has not been directed to another program or to a file.
      #
      sig { returns(T::Boolean) }
      def enable_color?
        @enable_color
      end

      # Turn colour in Formatter, Frame, and Spinner output on or off.
      #
      # ==== Attributes
      #
      # * +bool+ - true or false; enable or disable colour.
      #
      sig { params(bool: T::Boolean).void }
      def enable_color=(bool)
        @enable_color = !!bool
      end

      # Check whether cursor control is enabled in Formatter, Frame, and Spinner output.
      # By default, cursor control is enabled when STDOUT is a TTY; that is, when output
      # has not been directed to another program or to a file.
      #
      sig { returns(T::Boolean) }
      def enable_cursor?
        @enable_cursor
      end

      # Turn cursor control in Formatter, Frame, and Spinner output on or off.
      #
      # ==== Attributes
      #
      # * +bool+ - true or false; enable or disable cursor control.
      #
      sig { params(bool: T::Boolean).void }
      def enable_cursor=(bool)
        @enable_cursor = !!bool
      end

      # Set the default frame style.
      # Convenience method for setting the default frame style with +CLI::UI::Frame.frame_style=+
      #
      # Raises ArgumentError if +frame_style+ is not valid
      #
      # ==== Attributes
      #
      # * +symbol+ - the default frame style to use for frames
      #
      sig { params(frame_style: FrameStylable).void }
      def frame_style=(frame_style)
        Frame.frame_style = frame_style
      end

      # Create a terminal link
      sig { params(url: String, text: String, format: T::Boolean, blue_underline: T::Boolean).returns(String) }
      def link(url, text, format: true, blue_underline: format)
        raise 'cannot use blue_underline without format' if blue_underline && !format

        text = "{{blue:{{underline:#{text}}}}}" if blue_underline
        text = CLI::UI.fmt(text) if format
        "\x1b]8;;#{url}\x1b\\#{text}\x1b]8;;\x1b\\"
      end
    end

    self.enable_color = $stdout.tty?

    # Shopify's CI system supports color, but not cursor control
    self.enable_cursor = T.must($stdout.tty? && ENV['CI'].nil? && ENV['JOURNAL_STREAM'].nil?)
  end
end

require 'cli/ui/stdout_router'
