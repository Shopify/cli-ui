require 'io/console'

module CLI
  module UI
    module Prompt
      class InteractiveOptions
        DONE = "Done"
        CHECKBOX_ICON = { false => "☐", true => "☑" }

        # Prompts the user with options
        # Uses an interactive session to allow the user to pick an answer
        # Can use arrows, y/n, numbers (1/2), and vim bindings to control
        #
        # https://user-images.githubusercontent.com/3074765/33797984-0ebb5e64-dcdf-11e7-9e7e-7204f279cece.gif
        #
        # ==== Example Usage:
        #
        # Ask an interactive question
        #   CLI::UI::Prompt::InteractiveOptions.call(%w(rails go python))
        #
        def self.call(options, multiple: false)
          list = new(options, multiple: multiple)
          selected = list.call
          if multiple
            selected.map { |s| options[s - 1] }
          else
            options[selected - 1]
          end
        end

        # Initializes a new +InteractiveOptions+
        # Usually called from +self.call+
        #
        # ==== Example Usage:
        #
        #   CLI::UI::Prompt::InteractiveOptions.new(%w(rails go python))
        #
        def initialize(options, multiple: false)
          @options = options
          @active = 1
          @marker = '>'
          @answer = nil
          @state = :root
          @multiple = multiple
          # 0-indexed array representing if selected
          # @options[0] is selected if @chosen[0]
          @chosen = Array.new(@options.size) { false } if multiple
          @redraw = true
        end

        # Calls the +InteractiveOptions+ and asks the question
        # Usually used from +self.call+
        #
        def call
          CLI::UI.raw { print(ANSI.hide_cursor) }
          while @answer.nil?
            render_options
            process_input_until_redraw_required
            reset_position
          end
          clear_output
          @answer
        ensure
          CLI::UI.raw do
            print(ANSI.show_cursor)
            puts(ANSI.previous_line + ANSI.end_of_line)
          end
        end

        private

        def reset_position
          # This will put us back at the beginning of the options
          # When we redraw the options, they will be overwritten
          CLI::UI.raw do
            num_lines.times { print(ANSI.previous_line) }
            print(ANSI.previous_line + ANSI.end_of_line + "\n")
          end
        end

        def clear_output
          CLI::UI.raw do
            # Write over all lines with whitespace
            num_lines.times { puts(' ' * CLI::UI::Terminal.width) }
          end
          reset_position
        end

        def num_lines
          options = presented_options.map(&:first)
          # @options will be an array of questions but each option can be multi-line
          # so to get the # of lines, you need to join then split

          # empty_option_count is needed since empty option titles are omitted
          # from the line count when reject(&:empty?) is called

          empty_option_count = options.count(&:empty?)
          joined_options = options.join("\n")
          joined_options.split("\n").reject(&:empty?).size + empty_option_count
        end

        ESC = "\e"

        def up
          min_pos = @multiple ? 0 : 1
          @active = @active - 1 >= min_pos ? @active - 1 : @options.length
          @redraw = true
        end

        def down
          min_pos = @multiple ? 0 : 1
          @active = @active + 1 <= @options.length ? @active + 1 : min_pos
          @redraw = true
        end

        # n is 1-indexed selection
        # n == 0 if "Done" was selected in @multiple mode
        def select_n(n)
          if @multiple
            if n == 0
              @answer = []
              @chosen.each_with_index do |selected, i|
                @answer << i + 1 if selected
              end
            else
              @active = n
              @chosen[n - 1] = !@chosen[n - 1]
            end
          elsif n == 0
            # Ignore pressing "0" when not in multiple mode
          else
            @active = n
            @answer = n
          end
          @redraw = true
        end

        def select_bool(char)
          return unless (@options - %w(yes no)).empty?
          opt = @options.detect { |o| o.start_with?(char) }
          @active = @options.index(opt) + 1
          @answer = @options.index(opt) + 1
          @redraw = true
        end

        def select_current
          select_n(@active)
        end

        def process_input_until_redraw_required
          @redraw = false
          wait_for_user_input until @redraw
        end

        # rubocop:disable Style/WhenThen,Layout/SpaceBeforeSemicolon
        def wait_for_user_input
          char = read_char
          case @state
          when :root
            case char
            when :timeout                  ; raise Interrupt # Timeout, use interrupt to simulate
            when ESC                       ; @state = :esc
            when 'k'                       ; up
            when 'j'                       ; down
            when '0'                       ; select_n(char.to_i)
            when ('1'..@options.size.to_s) ; select_n(char.to_i)
            when 'y', 'n'                  ; select_bool(char)
            when " ", "\r", "\n"           ; select_current  # <enter>
            when "\u0003"                  ; raise Interrupt # Ctrl-c
            end
          when :esc
            case char
            when :timeout ; raise Interrupt # Timeout, use interrupt to simulate
            when '['      ; @state = :esc_bracket
            else          ; raise Interrupt # unhandled escape sequence.
            end
          when :esc_bracket
            @state = :root
            case char
            when :timeout ; raise Interrupt # Timeout, use interrupt to simulate
            when 'A'      ; up
            when 'B'      ; down
            else          ; raise Interrupt # unhandled escape sequence.
            end
          end
        end
        # rubocop:enable Style/WhenThen,Layout/SpaceBeforeSemicolon

        def read_char
          raw_tty! do
            getc = $stdin.getc
            getc ? getc.chr : :timeout
          end
        rescue IOError
          "\e"
        end

        def raw_tty!
          if ENV['TEST'] || !$stdin.tty?
            yield
          else
            $stdin.raw { yield }
          end
        end

        def presented_options(recalculate: false)
          return @presented_options unless recalculate

          @presented_options = @options.zip(1..Float::INFINITY)
          @presented_options.unshift([DONE, 0]) if @multiple

          while num_lines > max_options
            # try to keep the selection centered in the window:
            if distance_from_selection_to_end > distance_from_start_to_selection
              # selection is closer to top than bottom, so trim a row from the bottom
              ensure_last_item_is_continuation_marker
              @presented_options.delete_at(-2)
            else
              # selection is closer to bottom than top, so trim a row from the top
              ensure_first_item_is_continuation_marker
              @presented_options.delete_at(1)
            end
          end

          @presented_options
        end

        def distance_from_selection_to_end
          last_visible_option_number = @presented_options[-1].last || @presented_options[-2].last
          last_visible_option_number - @active
        end

        def distance_from_start_to_selection
          first_visible_option_number = @presented_options[0].last || @presented_options[1].last
          @active - first_visible_option_number
        end

        def ensure_last_item_is_continuation_marker
          @presented_options.push(["...", nil]) if @presented_options.last.last
        end

        def ensure_first_item_is_continuation_marker
          @presented_options.unshift(["...", nil]) if @presented_options.first.last
        end

        def max_options
          @max_options ||= CLI::UI::Terminal.height - 2 # Keeps a one line question visible
        end

        def render_options
          max_num_length = (@options.size + 1).to_s.length

          presented_options(recalculate: true).each do |choice, num|
            is_chosen = @multiple && num && @chosen[num - 1]

            padding = ' ' * (max_num_length - num.to_s.length)
            message = "  #{num}#{num ? '.' : ' '}#{padding}"

            format = "%s"
            # If multiple, bold only selected. If not multiple, bold everything
            format = "{{bold:#{format}}}" if !@multiple || is_chosen
            format = "{{cyan:#{format}}}" if @multiple && is_chosen && num != @active
            format = " #{format}"

            message += sprintf(format, CHECKBOX_ICON[is_chosen]) if @multiple && num && num > 0
            message += choice.split("\n").map { |l| sprintf(format, l) }.join("\n")

            if num == @active
              message = message.split("\n").map.with_index do |l, idx|
                idx == 0 ? "{{blue:> #{l.strip}}}" : "{{blue:>#{l.strip}}}"
              end.join("\n")
            end

            CLI::UI.with_frame_color(:blue) do
              puts CLI::UI.fmt(message) + CLI::UI::ANSI.clear_to_end_of_line
            end
          end
        end
      end
    end
  end
end
