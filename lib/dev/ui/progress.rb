require 'dev/ui'

module Dev
  module UI
    class Progress
      FILLED_BAR = Dev::UI::Glyph.new("◾", 0x2588, Color::CYAN)
      UNFILLED_BAR = Dev::UI::Glyph.new("◽", 0x2588, Color::WHITE)

      # Set the percent to X
      # Dev::UI::Progress.progress do |bar|
      #   bar.tick(set_percent: percent)
      # end
      #
      # Increase the percent by 1
      # Dev::UI::Progress.progress do |bar|
      #   bar.tick
      # end
      #
      # Increase the percent by X
      # Dev::UI::Progress.progress do |bar|
      #   bar.tick(percent: 5)
      # end
      def self.progress
        bar = Progress.new
        print Dev::UI::ANSI.hide_cursor
        yield(bar)
      ensure
        puts bar.to_s
        Dev::UI.raw do
          print(ANSI.show_cursor)
          puts(ANSI.previous_line + ANSI.end_of_line)
        end
      end

      def initialize(width: Terminal.width)
        @percent_done = 0
        @max_width = width
      end

      def tick(percent: 0.01, set_percent: nil)
        raise ArgumentError, 'percent and set_percent cannot both be specified' if percent != 0.01 && set_percent
        @percent_done += percent
        @percent_done = set_percent if set_percent
        @percent_done = [@percent_done, 1.0].min # Make sure we can't go above 1.0

        print to_s
        print Dev::UI::ANSI.previous_line
        print Dev::UI::ANSI.end_of_line + "\n"
      end

      def to_s
        suffix = " #{(@percent_done * 100).round(2)}%"
        workable_width = @max_width - Frame.prefix_width - suffix.size
        filled = (@percent_done * workable_width.to_f).ceil
        unfilled = workable_width - filled

        Dev::UI.resolve_text [
          (FILLED_BAR.to_s * filled),
          (UNFILLED_BAR.to_s * unfilled),
          suffix
        ].join
      end
    end
  end
end
