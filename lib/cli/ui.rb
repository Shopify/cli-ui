module CLI
  module UI
    autoload :ANSI,               'cli/ui/ansi'
    autoload :Glyph,              'cli/ui/glyph'
    autoload :Color,              'cli/ui/color'
    autoload :Box,                'cli/ui/box'
    autoload :Frame,              'cli/ui/frame'
    autoload :Progress,           'cli/ui/progress'
    autoload :Prompt,             'cli/ui/prompt'
    autoload :Terminal,           'cli/ui/terminal'
    autoload :Truncater,          'cli/ui/truncater'
    autoload :Formatter,          'cli/ui/formatter'
    autoload :Spinner,            'cli/ui/spinner'

    # Convenience accessor to +CLI::UI::Spinner::SpinGroup+
    SpinGroup = Spinner::SpinGroup

    # Glyph resolution using +CLI::UI::Glyph.lookup+
    # Look at the method signature for +Glyph.lookup+ for more details
    #
    # ==== Attributes
    #
    # * +handle+ - handle of the glyph to resolve
    #
    def self.glyph(handle)
      CLI::UI::Glyph.lookup(handle)
    end

    # Color resolution using +CLI::UI::Color.lookup+
    # Will lookup using +Color.lookup+ if a symbol, otherwise we assume it is a valid color and return it
    #
    # ==== Attributes
    #
    # * +input+ - color to resolve
    #
    def self.resolve_color(input)
      case input
      when Symbol
        CLI::UI::Color.lookup(input)
      else
        input
      end
    end

    # Conviencence Method for +CLI::UI::Prompt.confirm+
    #
    # ==== Attributes
    #
    # * +question+ - question to confirm
    #
    def self.confirm(question, **kwargs)
      CLI::UI::Prompt.confirm(question, **kwargs)
    end

    # Conviencence Method for +CLI::UI::Prompt.ask+
    #
    # ==== Attributes
    #
    # * +question+ - question to ask
    # * +kwargs+ - arugments for +Prompt.ask+
    #
    def self.ask(question, **kwargs)
      CLI::UI::Prompt.ask(question, **kwargs)
    end

    # Conviencence Method to resolve text using +CLI::UI::Formatter.format+
    # Check +CLI::UI::Formatter::SGR_MAP+ for available formatting options
    #
    # ==== Attributes
    #
    # * +input+ - input to format
    # * +truncate_to+ - number of characters to truncate the string to (or nil)
    #
    def self.resolve_text(input, truncate_to: nil)
      return input if input.nil?
      formatted = CLI::UI::Formatter.new(input).format
      return formatted unless truncate_to
      return CLI::UI::Truncater.call(formatted, truncate_to)
    end

    # Conviencence Method to format text using +CLI::UI::Formatter.format+
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
    def self.fmt(input, enable_color: enable_color?)
      CLI::UI::Formatter.new(input).format(enable_color: enable_color)
    end

    # Conviencence Method for +CLI::UI::Frame.open+
    #
    # ==== Attributes
    #
    # * +args+ - arguments for +Frame.open+
    # * +block+ - block for +Frame.open+
    #
    def self.frame(*args, &block)
      CLI::UI::Frame.open(*args, &block)
    end

    # Conviencence Method for +CLI::UI::Spinner.spin+
    #
    # ==== Attributes
    #
    # * +args+ - arguments for +Spinner.open+
    # * +block+ - block for +Spinner.open+
    #
    def self.spinner(*args, &block)
      CLI::UI::Spinner.spin(*args, &block)
    end

    # Conviencence Method to override frame color using +CLI::UI::Frame.with_frame_color+
    #
    # ==== Attributes
    #
    # * +color+ - color to override to
    # * +block+ - block for +Frame.with_frame_color_override+
    #
    def self.with_frame_color(color, &block)
      CLI::UI::Frame.with_frame_color_override(color, &block)
    end

    # Duplicate output to a file path
    #
    # ==== Attributes
    #
    # * +path+ - path to duplicate output to
    #
    def self.log_output_to(path)
      if CLI::UI::StdoutRouter.duplicate_output_to
        raise "multiple logs not allowed"
      end
      CLI::UI::StdoutRouter.duplicate_output_to = File.open(path, 'w')
      yield
    ensure
      if file_descriptor = CLI::UI::StdoutRouter.duplicate_output_to
        file_descriptor.close
        CLI::UI::StdoutRouter.duplicate_output_to = nil
      end
    end

    # Disable all framing within a block
    #
    # ==== Attributes
    #
    # * +block+ - block in which to disable frames
    #
    def self.raw
      prev = Thread.current[:no_cliui_frame_inset]
      Thread.current[:no_cliui_frame_inset] = true
      yield
    ensure
      Thread.current[:no_cliui_frame_inset] = prev
    end

    # Check whether colour is enabled in Formatter output. By default, colour
    # is enabled when STDOUT is a TTY; that is, when output has not been
    # redirected to another program or to a file.
    #
    def self.enable_color?
      @enable_color
    end

    # Turn colour output in Formatter on or off.
    #
    # ==== Attributes
    #
    # * +bool+ - true or false; enable or disable colour.
    #
    def self.enable_color=(bool)
      @enable_color = !!bool
    end

    self.enable_color = $stdout.tty?
  end
end

require 'cli/ui/stdout_router'
