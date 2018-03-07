require 'cli/ui'
require 'io/console'

module CLI
  module UI
    module Terminal
      DEFAULT_WIDTH = 80

      # Returns the width of the terminal, if possible
      # Otherwise will return 80
      #
      def self.width
        if console = IO.respond_to?(:console) && IO.console
          width = console.winsize[1]
          width.zero? ? DEFAULT_WIDTH : width
        else
          DEFAULT_WIDTH
        end
      rescue Errno::EIO
        DEFAULT_WIDTH
      end
    end
  end
end
