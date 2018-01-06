module CLI
  module UI
    module Prompt
      # A class that handles the various options of an InteractivePrompt and their callbacks
      class OptionsHandler
        def initialize
          @options = {}
        end

        def options
          @options.keys
        end

        def option(option, &handler)
          @options[option] = handler
        end

        def call(option)
          @options[option].call(option)
        end
      end
    end
  end
end
