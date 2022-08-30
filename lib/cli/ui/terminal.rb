# typed: true

require 'cli/ui'
require 'io/console'

module CLI
  module UI
    module Terminal
      extend T::Sig

      DEFAULT_WIDTH = 80
      DEFAULT_HEIGHT = 24

      class << self
        extend T::Sig

        # Returns the width of the terminal, if possible
        # Otherwise will return DEFAULT_WIDTH
        #
        sig { returns(Integer) }
        def width
          winsize[1]
        end

        # Returns the width of the terminal, if possible
        # Otherwise, will return DEFAULT_HEIGHT
        #
        sig { returns(Integer) }
        def height
          winsize[0]
        end

        sig { returns([Integer, Integer]) }
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

        sig { void }
        def setup_winsize_trap
          @winsize_trap ||= Signal.trap('WINCH') do
            @winsize = nil
          end
        end
      end
    end
  end
end
