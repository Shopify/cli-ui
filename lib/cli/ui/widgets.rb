# typed: true
# frozen_string_literal: true

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
      MAP = {}

      autoload(:Base, 'cli/ui/widgets/base')
      autoload(:Status, 'cli/ui/widgets/status')

      class << self
        #: (String name) { -> singleton(Widgets::Base) } -> void
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
        #: (String handle) -> singleton(Widgets::Base)
        def lookup(handle)
          MAP.fetch(handle).call
        rescue KeyError, NameError
          raise(InvalidWidgetHandle, handle)
        end

        # All available widgets by name
        #
        #: -> Array[String]
        def available
          MAP.keys
        end
      end

      register('status') { Widgets::Status }

      class InvalidWidgetHandle < ArgumentError
        #: (String handle) -> void
        def initialize(handle)
          super
          @handle = handle
        end

        #: -> String
        def message
          keys = Widgets.available.join(',')
          "invalid widget handle: #{@handle} " \
            "-- must be one of CLI::UI::Widgets.available (#{keys})"
        end
      end

      class InvalidWidgetArguments < ArgumentError
        #: (String argstring, Regexp pattern) -> void
        def initialize(argstring, pattern)
          super(nil)
          @argstring = argstring
          @pattern   = pattern
        end

        #: -> String
        def message
          "invalid widget arguments: #{@argstring} " \
            "-- must match pattern: #{@pattern.inspect}"
        end
      end
    end
  end
end
