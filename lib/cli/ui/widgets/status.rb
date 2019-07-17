# frozen-string-literal: true
require('cli/ui')

module CLI
  module UI
    module Widgets
      class Status < Widgets::Base
        ARGPARSE_PATTERN = %r{
          \A (?<succeeded> \d+)
          :  (?<failed>    \d+)
          :  (?<working>   \d+)
          :  (?<pending>   \d+) \z
        }x # e.g. "1:23:3:404"

        def render
          bold_reset = Color::RESET.code + Color::BOLD.code

          +''  \
            << bold_reset     << '[' << Color::RESET.code \
            << succeeded_part << ' ' \
            << failed_part    << ' ' \
            << working_part   << ' ' \
            << pending_part   << ''  \
            << bold_reset     << ']' << Color::RESET.code
        end

        private

        def colorize_if_nonzero(num_str, glyph, color)
          color = Color::GRAY if num_str == '0'
          color.code + num_str + glyph
        end

        def succeeded_part
          colorize_if_nonzero(@succeeded, Glyph::CHECK.char, Color::GREEN)
        end

        def failed_part
          colorize_if_nonzero(@failed, Glyph::X.char, Color::RED)
        end

        def working_part
          rune = @working == '0' ? CLI::UI::Spinner::RUNES[4] : Spinner.current_rune
          colorize_if_nonzero(@working, rune, Color::BLUE)
        end

        def pending_part
          colorize_if_nonzero(@pending, Glyph::HOURGLASS.char, Color::WHITE)
        end
      end
    end
  end
end
