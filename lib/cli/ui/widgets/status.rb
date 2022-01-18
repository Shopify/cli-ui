# typed: true
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
        OPEN  = Color::RESET.code + Color::BOLD.code + '[' + Color::RESET.code
        CLOSE = Color::RESET.code + Color::BOLD.code + ']' + Color::RESET.code
        ARROW = Color::RESET.code + Color::GRAY.code + '◂' + Color::RESET.code
        COMMA = Color::RESET.code + Color::GRAY.code + ',' + Color::RESET.code

        SPINNER_STOPPED = '⠿'
        EMPTY_SET = '∅'

        sig { override.returns(T.untyped) }
        def self.argparse_pattern
          ARGPARSE_PATTERN
        end

        sig { returns(T.untyped) }
        def render
          if zero?(@succeeded) && zero?(@failed) && zero?(@working) && zero?(@pending)
            Color::RESET.code + Color::BOLD.code + EMPTY_SET + Color::RESET.code
          else
            #   [          0✓            ,         2✗          ◂         3⠼           ◂         4⌛︎           ]
            "#{OPEN}#{succeeded_part}#{COMMA}#{failed_part}#{ARROW}#{working_part}#{ARROW}#{pending_part}#{CLOSE}"
          end
        end

        private

        sig { params(num_str: T.untyped).returns(T.untyped) }
        def zero?(num_str)
          num_str == '0'
        end

        sig { params(num_str: T.untyped, rune: T.untyped, color: T.untyped).returns(T.untyped) }
        def colorize_if_nonzero(num_str, rune, color)
          color = Color::GRAY if zero?(num_str)
          color.code + num_str + rune
        end

        sig { returns(T.untyped) }
        def succeeded_part
          colorize_if_nonzero(@succeeded, Glyph::CHECK.char, Color::GREEN)
        end

        sig { returns(T.untyped) }
        def failed_part
          colorize_if_nonzero(@failed, Glyph::X.char, Color::RED)
        end

        sig { returns(T.untyped) }
        def working_part
          rune = zero?(@working) ? SPINNER_STOPPED : Spinner.current_rune
          colorize_if_nonzero(@working, rune, Color::BLUE)
        end

        sig { returns(T.untyped) }
        def pending_part
          colorize_if_nonzero(@pending, Glyph::HOURGLASS.char, Color::WHITE)
        end
      end
    end
  end
end
