# typed: true
# frozen_string_literal: true

require('cli/ui')

module CLI
  module UI
    module Widgets
      # @abstract
      class Base
        class << self
          #: (String argstring) -> String
          def call(argstring)
            new(argstring).render
          end
        end

        #: (String argstring) -> void
        def initialize(argstring)
          pat = self.class.argparse_pattern
          unless (@match_data = pat.match(argstring))
            raise(Widgets::InvalidWidgetArguments.new(argstring, pat))
          end

          @match_data.names.each do |name|
            instance_variable_set(:"@#{name}", @match_data[name])
          end
        end

        class << self
          # @abstract
          #: -> Regexp
          def argparse_pattern
            raise(NotImplementedError)
          end
        end

        # @abstract
        #: -> String
        def render
          raise(NotImplementedError)
        end
      end
    end
  end
end
