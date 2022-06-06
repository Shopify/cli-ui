# typed: true

module CLI
  module UI
    module Prompt
      # A class that handles the various options of an InteractivePrompt and their callbacks
      class OptionsHandler
        extend T::Sig

        sig { void }
        def initialize
          @options = {}
        end

        sig { returns(T::Array[String]) }
        def options
          @options.keys
        end

        sig { params(option: String, handler: T.proc.params(option: String).returns(String)).void }
        def option(option, &handler)
          @options[option] = handler
        end

        sig { params(options: T.any(T::Array[String], String)).returns(String) }
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
