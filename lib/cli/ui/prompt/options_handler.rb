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

        def call(options)
          case options
          when Array
            # Slice out the handlers and call each with the option they're for
            @options.values_at(*options).each_with_index.map do |handler, index|
              handler.call(options[index])
            end
          else
            @options[options].call(options)
          end
        end
      end
    end
  end
end
