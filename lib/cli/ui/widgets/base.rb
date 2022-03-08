# typed: true
require('cli/ui')

module CLI
  module UI
    module Widgets
      class Base
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { params(argstring: String).returns(String) }
        def self.call(argstring)
          new(argstring).render
        end

        sig { params(argstring: String).void }
        def initialize(argstring)
          pat = self.class.argparse_pattern
          unless (@match_data = pat.match(argstring))
            raise(Widgets::InvalidWidgetArguments.new(argstring, pat))
          end

          @match_data.names.each do |name|
            instance_variable_set(:"@#{name}", @match_data[name])
          end
        end

        sig { abstract.returns(Regexp) }
        def self.argparse_pattern; end

        sig { abstract.returns(String) }
        def render; end
      end
    end
  end
end
