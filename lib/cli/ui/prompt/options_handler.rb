# typed: true
module CLI
  module UI
    module Prompt
      # A class that handles the various options of an InteractivePrompt and their callbacks
      class OptionsHandler
        sig { returns(T.untyped) }
        def initialize
          @options = {}
        end

        sig { returns(T.untyped) }
        def options
          @options.keys
        end

        sig { params(option: T.untyped, handler: T.untyped).returns(T.untyped) }
        def option(option, &handler)
          @options[option] = handler
        end

        sig { params(options: T.untyped).returns(T.untyped) }
        def call(options)
          case options
          when Array
            options.map { |option| @options[option].call(options) }
          else
            @options[options].call(options)
          end
        end
      end
    end
  end
end
