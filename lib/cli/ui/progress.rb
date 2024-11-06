# typed: true
# frozen_string_literal: true

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
        #
        # Update the title
        #   CLI::UI::Progress.progress('Title') do |bar|
        #     bar.tick(percent: 0.05)
        #     bar.update_title('New title')
        #   end
        sig do
          type_parameters(:T)
            .params(
              title: T.nilable(String),
              width: Integer,
              block: T.proc.params(bar: Progress).returns(T.type_parameter(:T)),
            )
            .returns(T.type_parameter(:T))
        end
        def progress(title = nil, width: Terminal.width, &block)
          bar = Progress.new(title, width: width)
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
      #
      # * +:title+ - The title of the progress bar
      # * +:width+ - The width of the terminal
      #
      sig { params(title: T.nilable(String), width: Integer).void }
      def initialize(title = nil, width: Terminal.width)
        @percent_done = T.let(0, Numeric)
        @title = title
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

        printed_lines = @title ? 2 : 1
        print(CLI::UI::ANSI.previous_lines(printed_lines) + "\n")
      end

      # Update the progress bar title
      #
      # ==== Attributes
      #
      # * +new_title+ - title to change the progress bar to
      #
      sig { params(new_title: String).void }
      def update_title(new_title)
        @title = new_title
      end

      # Format the progress bar to be printed to terminal
      #
      sig { returns(String) }
      def to_s
        suffix = " #{(@percent_done * 100).floor}%".ljust(5)
        workable_width = @max_width - Frame.prefix_width - suffix.size
        filled = [(@percent_done * workable_width.to_f).ceil, 0].max
        unfilled = [workable_width - filled, 0].max

        title = CLI::UI.resolve_text(@title, truncate_to: @max_width - Frame.prefix_width) if @title
        bar = CLI::UI.resolve_text([
          FILLED_BAR + ' ' * filled,
          UNFILLED_BAR + ' ' * unfilled,
          CLI::UI::Color::RESET.code + suffix,
        ].join)

        [title, bar].compact.join("\n")
      end
    end
  end
end
