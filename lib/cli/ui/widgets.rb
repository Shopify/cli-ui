require('cli/ui')

module CLI
  module UI
    module Widgets
      MAP = {}

      def self.register(const, name, path)
        autoload(const, path)
        MAP[name] = const
      end

      autoload(:Base,             'cli/ui/widgets/base')
      register(:Status, 'status', 'cli/ui/widgets/status')

      # Looks up a widget by handle
      #
      # ==== Raises
      # Raises InvalidWidgetHandle if the widget is not available.
      #
      # ==== Returns
      # A callable widget, to be invoked like `.call(argstring)`
      #
      def self.lookup(handle)
        const_get(MAP.fetch(handle.to_s))
      rescue KeyError, NameError
        raise(InvalidWidgetHandle, handle)
      end

      # All available widgets by name
      #
      def self.available
        MAP.keys
      end

      class InvalidWidgetHandle < ArgumentError
        def initialize(handle)
          @handle = handle
        end

        def message
          keys = Widget.available.join(',')
          "invalid widget handle: #{@handle} " \
            "-- must be one of CLI::UI::Widgets.available (#{keys})"
        end
      end

      class InvalidWidgetArguments < ArgumentError
        def initialize(argstring, pattern)
          @argstring = argstring
          @pattern   = pattern
        end

        def message
          "invalid widget arguments: #{@argstring} " \
            "-- must match pattern: #{@pattern.inspect}"
        end
      end
    end
  end
end
