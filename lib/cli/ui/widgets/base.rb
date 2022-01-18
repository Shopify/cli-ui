# typed: true
require('cli/ui')

module CLI
  module UI
    module Widgets
      class Base
        extend T::Sig

        sig { params(argstring: T.untyped).returns(T.untyped) }
        def self.call(argstring)
          new(argstring).render
        end

        sig { params(argstring: T.untyped).void }
        def initialize(argstring)
          pat = self.class.argparse_pattern
          unless (@match_data = pat.match(argstring))
            raise(Widgets::InvalidWidgetArguments.new(argstring, pat))
          end
          @match_data.names.each do |name|
            instance_variable_set(:"@#{name}", @match_data[name])
          end
        end

        sig { returns(T.untyped) }
        def self.argparse_pattern
          const_get(:ARGPARSE_PATTERN)
        end
      end
    end
  end
end
