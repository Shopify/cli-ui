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


    # TODO: this, better
    SpinGroup = Spinner::SpinGroup

    # TODO: test
    def self.glyph(handle)
      Dev::UI::Glyph.lookup(handle)
    end

    # TODO: test
    def self.resolve_color(input)
      case input
      when Symbol
        Dev::UI::Color.lookup(input)
      else
        input
      end
    end

    def self.confirm(question)
      Dev::UI::Prompt.confirm(question)
    end

    def self.ask(question, **kwargs)
      Dev::UI::Prompt.ask(question, **kwargs)
    end

    def self.resolve_text(input)
      return input if input.nil?
      Dev::UI::Formatter.new(input).format
    end

    def self.fmt(input, enable_color: true)
      Dev::UI::Formatter.new(input).format(enable_color: enable_color)
    end

    def self.frame(*args, &block)
      Dev::UI::Frame.open(*args, &block)
    end

    def self.spinner(*args, &block)
      Dev::UI::Spinner.spin(*args, &block)
    end

    def self.with_frame_color(color, &block)
      Dev::UI::Frame.with_frame_color_override(color, &block)
    end

    def self.log_output_to(path)
      if Dev::UI::StdoutRouter.duplicate_output_to
        raise "multiple logs not allowed"
      end
      Dev::UI::StdoutRouter.duplicate_output_to = File.open(path, 'w')
      yield
    ensure
      f = Dev::UI::StdoutRouter.duplicate_output_to
      f.close
      Dev::UI::StdoutRouter.duplicate_output_to = nil
    end

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
