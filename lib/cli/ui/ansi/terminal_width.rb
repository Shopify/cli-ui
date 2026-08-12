# typed: true
# frozen_string_literal: true

require_relative 'width_data'

module CLI
  module UI
    module ANSI
      # Internal terminal-column measurements used by ANSI replay. Existing
      # layout APIs keep their current width behavior until they deliberately
      # adopt this implementation.
      module TerminalWidth
        VS16 = 0xFE0F

        class << self
          # The number of terminal columns occupied by one grapheme cluster.
          #
          #: (String cluster) -> Integer
          def grapheme_width(cluster)
            case cluster
            when "\n", "\r", "\r\n"
              0
            else
              codepoint = cluster.ord
              wide = WIDE_RANGES.bsearch do |range|
                if codepoint < range.begin
                  -1
                elsif codepoint > range.end
                  1
                else
                  0
                end
              end
              return 2 if wide

              cluster.length > 1 && cluster.each_codepoint.include?(VS16) ? 2 : 1
            end
          end
        end
      end
      private_constant :TerminalWidth
    end
  end
end
