require 'dev/ui'

module Dev
  module UI
    module Spinner
      autoload :Async,      'dev/ui/spinner/async'
      autoload :SpinGroup,  'dev/ui/spinner/spin_group'

      PERIOD = 0.1 # seconds
      TASK_FAILED = :task_failed

      begin
        runes = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        colors = [Dev::UI::Color::CYAN.code] * 5 + [Dev::UI::Color::MAGENTA.code] * 5
        raise unless runes.size == colors.size
        GLYPHS = colors.zip(runes).map(&:join)
      end

      # Adds a single spinner
      # Uses an interactive session to allow the user to pick an answer
      # Can use arrows, y/n, numbers (1/2), and vim bindings to control
      #
      # https://user-images.githubusercontent.com/3074765/33798295-d94fd822-dce3-11e7-819b-43e5502d490e.gif
      #
      # ==== Attributes
      #
      # * +title+ - Title of the spinner to use
      #
      # ==== Options
      #
      # * +:auto_debrief+ - Automatically debrief exceptions? Default to true
      #
      # ==== Block
      #
      # * *spinner+ - Instance of the spinner. Can call +update_title+ to update the user of changes
      #
      # ==== Example Usage:
      #
      #   Dev::UI::Spinner.spin('Title') { sleep 1.0 }
      #
      def self.spin(title, auto_debrief: true, &block)
        sg = SpinGroup.new(auto_debrief: auto_debrief)
        sg.add(title, &block)
        sg.wait
      end
    end
  end
end
