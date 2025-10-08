# typed: true
# frozen_string_literal: true

require 'cli/ui'
require 'io/console'

module CLI
  module UI
    module Terminal
      DEFAULT_WIDTH = 80
      DEFAULT_HEIGHT = 24

      class << self
        # Returns the width of the terminal, if possible
        # Otherwise will return DEFAULT_WIDTH
        #
        #: -> Integer
        def width
          winsize[1]
        end

        # Returns the width of the terminal, if possible
        # Otherwise, will return DEFAULT_HEIGHT
        #
        #: -> Integer
        def height
          winsize[0]
        end

        #: -> [Integer, Integer]
        def winsize
          @winsize ||= begin
            winsize = IO.console.winsize
            setup_winsize_trap

            if winsize.any?(&:zero?)
              [DEFAULT_HEIGHT, DEFAULT_WIDTH]
            else
              winsize
            end
          rescue
            [DEFAULT_HEIGHT, DEFAULT_WIDTH]
          end
        end

        #: -> void
        def setup_winsize_trap
          @winsize_trap ||= Signal.trap('WINCH') do
            @winsize = nil
          end
        end
      end
    end
  end
end
