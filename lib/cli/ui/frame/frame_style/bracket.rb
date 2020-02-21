module CLI
  module UI
    module Frame
      module FrameStyle
        module Bracket
          extend FrameStyle

          VERTICAL    = '┃'
          HORIZONTAL  = '━'
          DIVIDER     = "┣"
          TOP_LEFT    = '┏'
          BOTTOM_LEFT = '┗'

          class << self
            def to_s
              'bracket'
            end

            def prefix
              VERTICAL
            end

            def prefix_width
              CLI::UI::ANSI.printing_width(prefix)
            end

            def open(text, color:)
              edge(text, color: color, first: TOP_LEFT)
            end

            def divider(text, color:)
              edge(text, color: color, first: DIVIDER)
            end

            def close(text, color:, right_text: nil)
              edge(text, color: color, right_text: right_text, first: BOTTOM_LEFT)
            end

            private

            def edge(text, color:, first:, right_text: nil)
              color = CLI::UI.resolve_color(color)

              preamble = +''

              preamble << color.code << first << (HORIZONTAL * 2)

              text ||= ''
              unless text.empty?
                preamble << ' ' << CLI::UI.resolve_text("{{#{color.name}:#{text}}}") << ' '
              end

              suffix = +''

              if right_text
                suffix << ' ' << right_text << ' '
              end

              o = +''

              o << color.code << preamble
              o << color.code << suffix
              o << CLI::UI::Color::RESET.code
              o << "\n"

              o
            end
          end
        end
      end
    end
  end
end
