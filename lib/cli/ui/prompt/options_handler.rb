# typed: true
# frozen_string_literal: true

module CLI
  module UI
    module Prompt
      # A class that handles the various options of an InteractivePrompt and their callbacks
      class OptionsHandler
        #: -> void
        def initialize
          @options = {}
        end

        #: -> Array[String]
        def options
          @options.keys
        end

        #: (String option) { (String option) -> String } -> void
        def option(option, &handler)
          @options[option] = handler
        end

        #: ((Array[String] | String) options) -> String
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
