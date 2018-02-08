require 'cli/ui'

module CLI
  module UI
    module ANSI
      # ANSI escape sequences (like \x1b[31m) have zero width.
      # when calculating the padding width, we must exclude them.
      # This also implements a basic version of utf8 character width calculation like
      # we could get for real from something like utf8proc.
      #
      def self.printing_width(str)
        zwj = false
        strip_codes(str).codepoints.reduce(0) do |acc, cp|
          if zwj
            zwj = false
            next acc
          end
          case cp
          when 0x200d # zero-width joiner
            zwj = true
            acc
          else
            acc + 1
          end
        end
      end

      # Strips ANSI codes from a str
      #
      # ==== Attributes
      #
      # - +str+ - The string from which to strip codes
      #
      def self.strip_codes(str)
        str.gsub(/\x1b\[[\d;]+[A-z]|\r/, '')
      end

      # https://en.wikipedia.org/wiki/ANSI_escape_code#graphics
      def self.sgr(params)
        "\x1b[#{params}m"
      end
    end
  end
end
