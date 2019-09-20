require 'cli/ui'
require 'io/console'

module CLI
  module UI
    module Terminal
      DEFAULT_WIDTH = 80
      DEFAULT_HEIGHT = 24

      @console = begin
                   IO.respond_to?(:console) && IO.console
                 rescue Errno::EIO
                   false
                 end

      # Returns the width of the terminal, if possible
      # Otherwise will return DEFAULT_WIDTH
      #
      def self.width
        @width ||= begin
                     if @console
                       width = @console.winsize[1]
                       width.zero? ? DEFAULT_WIDTH : width
                     else
                       DEFAULT_WIDTH
                     end
                   rescue Errno::EIO
                     DEFAULT_WIDTH
                   end
      end

      # Returns the width of the terminal, if possible
      # Otherwise, will return DEFAULT_HEIGHT
      #
      def self.height
        @height ||= begin
                      if @console
                        height = @console.winsize[0]
                        height.zero? ? DEFAULT_HEIGHT : height
                      else
                        DEFAULT_HEIGHT
                      end
                    rescue Errno::EIO
                      DEFAULT_HEIGHT
                    end
      end

      def self.reset_cache
        @width = nil
        @height = nil
      end
    end
  end
end

Signal.trap('WINCH') do
  CLI::UI::Terminal.reset_cache
end
