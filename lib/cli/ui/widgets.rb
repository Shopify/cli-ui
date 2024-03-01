# typed: true

require('cli/ui')

module CLI
  module UI
    # Widgets are formatter objects with more custom implementations than the
    # other features, which all center around formatting text with colours,
    # etc.
    #
    # If you want to extend CLI::UI with your own widgets, you may want to do
    # something like this:
    #
    #   require('cli/ui')
    #   class MyWidget < CLI::UI::Widgets::Base
    #     # ...
    #   end
    #   CLI::UI::Widgets.register('my-widget') { MyWidget }
    #   puts(CLI::UI.fmt("{{@widget/my-widget:args}}"))
    module Widgets
      extend T::Sig

      MAP = {}

      autoload(:Base, 'cli/ui/widgets/base')
      autoload(:Status, 'cli/ui/widgets/status')

      class << self
        extend T::Sig

        sig { params(name: String, cb: T.proc.returns(T.class_of(Widgets::Base))).void }
        def register(name, &cb)
          MAP[name] = cb
        end

        # Looks up a widget by handle
        #
        # ==== Raises
        # Raises InvalidWidgetHandle if the widget is not available.
        #
        # ==== Returns
        # A callable widget, to be invoked like `.call(argstring)`
        #
        sig { params(handle: String).returns(T.class_of(Widgets::Base)) }
        def lookup(handle)
          MAP.fetch(handle).call
        rescue KeyError, NameError
          raise(InvalidWidgetHandle, handle)
        end

        # All available widgets by name
        #
        sig { returns(T::Array[String]) }
        def available
          MAP.keys
        end
      end

      register('status') { Widgets::Status }

      class InvalidWidgetHandle < ArgumentError
        extend T::Sig

        sig { params(handle: String).void }
        def initialize(handle)
          super
          @handle = handle
        end

        sig { returns(String) }
        def message
          keys = Widgets.available.join(',')
          "invalid widget handle: #{@handle} " \
            "-- must be one of CLI::UI::Widgets.available (#{keys})"
        end
      end

      class InvalidWidgetArguments < ArgumentError
        extend T::Sig

        sig { params(argstring: String, pattern: Regexp).void }
        def initialize(argstring, pattern)
          super(nil)
          @argstring = argstring
          @pattern   = pattern
        end

        sig { returns(String) }
        def message
          "invalid widget arguments: #{@argstring} " \
            "-- must match pattern: #{@pattern.inspect}"
        end
      end
    end
  end
end
