# typed: true
# frozen_string_literal: true

module CLI
  module UI
    module Spinner
      extend T::Sig

      PERIOD = 0.1 # seconds
      TASK_FAILED = :task_failed

      RUNES = if CLI::UI::OS.current.use_emoji?
        ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'].freeze
      else
        ['\\', '|', '/', '-', '\\', '|', '/', '-'].freeze
      end

      colors = [CLI::UI::Color::CYAN.code] * (RUNES.size / 2).ceil +
        [CLI::UI::Color::MAGENTA.code] * (RUNES.size / 2).to_i
      GLYPHS = colors.zip(RUNES).map { |c, r| c + r + CLI::UI::Color::RESET.code }.freeze

      class << self
        extend T::Sig

        sig { returns(T.nilable(Integer)) }
        attr_accessor(:index)

        # We use this from CLI::UI::Widgets::Status to render an additional
        # spinner next to the "working" element. While this global state looks
        # a bit repulsive at first, it's worth realizing that:
        #
        # * It's managed by the SpinGroup#wait method, not individual tasks; and
        # * It would be complete insanity to run two separate but concurrent SpinGroups.
        #
        # While it would be possible to stitch through some connection between
        # the SpinGroup and the Widgets included in its title, this is simpler
        # in practice and seems unlikely to cause issues in practice.
        sig { returns(String) }
        def current_rune
          RUNES[index || 0]
        end
      end

      class << self
        extend T::Sig

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
        # * +:auto_debrief+ - Automatically debrief exceptions or through success_debrief? Default to true
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with print and puts methods,
        #   or under Sorbet, IO or StringIO. Defaults to $stdout.
        #
        # ==== Block
        #
        # * *spinner+ - Instance of the spinner. Can call +update_title+ to update the user of changes
        #
        # ==== Example Usage:
        #
        #   CLI::UI::Spinner.spin('Title') { sleep 1.0 }
        #
        sig do
          params(
            title: String,
            auto_debrief: T::Boolean,
            to: IOLike,
            block: T.proc.params(task: SpinGroup::Task).void,
          ).returns(T::Boolean)
        end
        def spin(title, auto_debrief: true, to: $stdout, &block)
          sg = SpinGroup.new(auto_debrief: auto_debrief)
          sg.add(title, &block)
          sg.wait(to: to)
        end
      end
    end
  end
end
