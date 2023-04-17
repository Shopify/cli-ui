# typed: true

require 'cli/ui'

module CLI
  module UI
    class Progress
      extend T::Sig

      # A Cyan filled block
      FILLED_BAR = "\e[46m"
      # A bright white block
      UNFILLED_BAR = "\e[1;47m"

      class << self
        extend T::Sig

        # Add a progress bar to the terminal output
        #
        # https://user-images.githubusercontent.com/3074765/33799794-cc4c940e-dd00-11e7-9bdc-90f77ec9167c.gif
        #
        # ==== Example Usage:
        #
        # Set the percent to X
        #   CLI::UI::Progress.progress do |bar|
        #     bar.tick(set_percent: percent)
        #   end
        #
        # Increase the percent by 1 percent
        #   CLI::UI::Progress.progress do |bar|
        #     bar.tick
        #   end
        #
        # Increase the percent by X
        #   CLI::UI::Progress.progress do |bar|
        #     bar.tick(percent: 0.05)
        #   end
        sig do
          type_parameters(:T)
            .params(width: Integer, block: T.proc.params(bar: Progress).returns(T.type_parameter(:T)))
            .returns(T.type_parameter(:T))
        end
        def progress(width: Terminal.width, &block)
          bar = Progress.new(width: width)
          print(CLI::UI::ANSI.hide_cursor)
          yield(bar)
        ensure
          puts(bar)
          CLI::UI.raw do
            print(ANSI.show_cursor)
          end
        end
      end

      # Initialize a progress bar. Typically used in a +Progress.progress+ block
      #
      # ==== Options
      # One of the follow can be used, but not both together
      #
      # * +:width+ - The width of the terminal
      #
      sig { params(width: Integer).void }
      def initialize(width: Terminal.width)
        @percent_done = T.let(0, Numeric)
        @max_width = width
      end

      # Set the progress of the bar. Typically used in a +Progress.progress+ block
      #
      # ==== Options
      # One of the follow can be used, but not both together
      #
      # * +:percent+ - Increment progress by a specific percent amount
      # * +:set_percent+ - Set progress to a specific percent
      #
      # *Note:* The +:percent+ and +:set_percent must be between 0.00 and 1.0
      #
      sig { params(percent: T.nilable(Numeric), set_percent: T.nilable(Numeric)).void }
      def tick(percent: nil, set_percent: nil)
        raise ArgumentError, 'percent and set_percent cannot both be specified' if percent && set_percent

        @percent_done += percent || 0.01
        @percent_done = set_percent if set_percent
        @percent_done = [@percent_done, 1.0].min # Make sure we can't go above 1.0

        print(self)
        print(CLI::UI::ANSI.previous_line + "\n")
      end

      # Format the progress bar to be printed to terminal
      #
      sig { returns(String) }
      def to_s
        suffix = " #{(@percent_done * 100).floor}%".ljust(5)
        workable_width = @max_width - Frame.prefix_width - suffix.size
        filled = [(@percent_done * workable_width.to_f).ceil, 0].max
        unfilled = [workable_width - filled, 0].max

        CLI::UI.resolve_text([
          FILLED_BAR + ' ' * filled,
          UNFILLED_BAR + ' ' * unfilled,
          CLI::UI::Color::RESET.code + suffix,
        ].join)
      end
    end
  end
end
