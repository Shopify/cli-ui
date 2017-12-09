module Dev
  module UI
    autoload :ANSI,               'dev/ui/ansi'
    autoload :Glyph,              'dev/ui/glyph'
    autoload :Color,              'dev/ui/color'
    autoload :Box,                'dev/ui/box'
    autoload :Frame,              'dev/ui/frame'
    autoload :InteractivePrompt,  'dev/ui/interactive_prompt'
    autoload :Progress,           'dev/ui/progress'
    autoload :Prompt,             'dev/ui/prompt'
    autoload :Terminal,           'dev/ui/terminal'
    autoload :Formatter,          'dev/ui/formatter'
    autoload :Spinner,            'dev/ui/spinner'

    # Convenience accessor to +Dev::UI::Spinner::SpinGroup+
    SpinGroup = Spinner::SpinGroup

    # Glyph resolution using +Dev::UI::Glyph.lookup+
    # Look at the method signature for +Glyph.lookup+ for more details
    #
    # ==== Attributes
    #
    # * +handle+ - handle of the glyph to resolve
    #
    def self.glyph(handle)
      Dev::UI::Glyph.lookup(handle)
    end

    # Color resolution using +Dev::UI::Color.lookup+
    # Will lookup using +Color.lookup+ if a symbol, otherwise we assume it is a valid color and return it
    #
    # ==== Attributes
    #
    # * +input+ - color to resolve
    #
    def self.resolve_color(input)
      case input
      when Symbol
        Dev::UI::Color.lookup(input)
      else
        input
      end
    end

    # Conviencence Method for +Dev::UI::Prompt.confirm+
    #
    # ==== Attributes
    #
    # * +question+ - question to confirm
    #
    def self.confirm(question)
      Dev::UI::Prompt.confirm(question)
    end

    # Conviencence Method for +Dev::UI::Prompt.ask+
    #
    # ==== Attributes
    #
    # * +question+ - question to ask
    # * +kwargs+ - arugments for +Prompt.ask+
    #
    def self.ask(question, **kwargs)
      Dev::UI::Prompt.ask(question, **kwargs)
    end

    # Conviencence Method to resolve text using +Dev::UI::Formatter.format+
    # Check +Dev::UI::Formatter::SGR_MAP+ for available formatting options
    #
    # ==== Attributes
    #
    # * +input+ - input to format
    #
    def self.resolve_text(input)
      return input if input.nil?
      Dev::UI::Formatter.new(input).format
    end

    # Conviencence Method to format text using +Dev::UI::Formatter.format+
    # Check +Dev::UI::Formatter::SGR_MAP+ for available formatting options
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
    # * +enable_color+ - should color be used? default to true
    #
    def self.fmt(input, enable_color: true)
      Dev::UI::Formatter.new(input).format(enable_color: enable_color)
    end

    # Conviencence Method for +Dev::UI::Frame.open+
    #
    # ==== Attributes
    #
    # * +args+ - arguments for +Frame.open+
    # * +block+ - block for +Frame.open+
    #
    def self.frame(*args, &block)
      Dev::UI::Frame.open(*args, &block)
    end

    # Conviencence Method for +Dev::UI::Spinner.spin+
    #
    # ==== Attributes
    #
    # * +args+ - arguments for +Spinner.open+
    # * +block+ - block for +Spinner.open+
    #
    def self.spinner(*args, &block)
      Dev::UI::Spinner.spin(*args, &block)
    end

    # Conviencence Method to override frame color using +Dev::UI::Frame.with_frame_color+
    #
    # ==== Attributes
    #
    # * +color+ - color to override to
    # * +block+ - block for +Frame.with_frame_color_override+
    #
    def self.with_frame_color(color, &block)
      Dev::UI::Frame.with_frame_color_override(color, &block)
    end

    # Duplicate output to a file path
    #
    # ==== Attributes
    #
    # * +path+ - path to duplicate output to
    #
    def self.log_output_to(path)
      if Dev::UI::StdoutRouter.duplicate_output_to
        raise "multiple logs not allowed"
      end
      Dev::UI::StdoutRouter.duplicate_output_to = File.open(path, 'w')
      yield
    ensure
      if file_descriptor = Dev::UI::StdoutRouter.duplicate_output_to
        file_descriptor.close 
        Dev::UI::StdoutRouter.duplicate_output_to = nil
      end
    end

    # Disable all framing within a block
    #
    # ==== Attributes
    #
    # * +block+ - block in which to disable frames
    #
    def self.raw
      prev = Thread.current[:no_devui_frame_inset]
      Thread.current[:no_devui_frame_inset] = true
      yield
    ensure
      Thread.current[:no_devui_frame_inset] = prev
    end
  end
end

require 'dev/ui/stdout_router'
