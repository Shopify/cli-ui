# typed: true
# frozen_string_literal: true

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
        OPEN  = Color::RESET.code + Color::BOLD.code + '[' + Color::RESET.code
        CLOSE = Color::RESET.code + Color::BOLD.code + ']' + Color::RESET.code
        ARROW = Color::RESET.code + Color::GRAY.code + '◂' + Color::RESET.code
        COMMA = Color::RESET.code + Color::GRAY.code + ',' + Color::RESET.code

        SPINNER_STOPPED = '⠿'
        EMPTY_SET = '∅'

        class << self
          # @override
          #: -> Regexp
          def argparse_pattern
            ARGPARSE_PATTERN
          end
        end

        # @override
        #: -> String
        def render
          if zero?(@succeeded) && zero?(@failed) && zero?(@working) && zero?(@pending)
            Color::RESET.code + Color::BOLD.code + EMPTY_SET + Color::RESET.code
          else
            #   [          0✓            ,         2✗          ◂         3⠼           ◂         4⌛︎           ]
            "#{OPEN}#{succeeded_part}#{COMMA}#{failed_part}#{ARROW}#{working_part}#{ARROW}#{pending_part}#{CLOSE}"
          end
        end

        private

        #: (String num_str) -> bool
        def zero?(num_str)
          num_str == '0'
        end

        #: (String num_str, String rune, Color color) -> String
        def colorize_if_nonzero(num_str, rune, color)
          color = Color::GRAY if zero?(num_str)
          color.code + num_str + rune
        end

        #: -> String
        def succeeded_part
          colorize_if_nonzero(@succeeded, Glyph::CHECK.char, Color::GREEN)
        end

        #: -> String
        def failed_part
          colorize_if_nonzero(@failed, Glyph::X.char, Color::RED)
        end

        #: -> String
        def working_part
          rune = zero?(@working) ? SPINNER_STOPPED : Spinner.current_rune
          colorize_if_nonzero(@working, rune, Color::BLUE)
        end

        #: -> String
        def pending_part
          colorize_if_nonzero(@pending, Glyph::HOURGLASS.char, Color::WHITE)
        end
      end
    end
  end
end
