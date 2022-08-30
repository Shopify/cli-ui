# typed: true

module CLI
  module UI
    module Spinner
      class Async
        extend T::Sig

        class << self
          extend T::Sig

          # Convenience method for +initialize+
          #
          sig { params(title: String).returns(Async) }
          def start(title)
            new(title)
          end
        end

        # Initializes a new asynchronous spinner with no specific end.
        # Must call +.stop+ to end the spinner
        #
        # ==== Attributes
        #
        # * +title+ - Title of the spinner to use
        #
        # ==== Example Usage:
        #
        #   CLI::UI::Spinner::Async.new('Title')
        #
        sig { params(title: String).void }
        def initialize(title)
          require 'thread'
          sg = CLI::UI::Spinner::SpinGroup.new
          @m = Mutex.new
          @cv = ConditionVariable.new
          sg.add(title) { @m.synchronize { @cv.wait(@m) } }
          @t = Thread.new { sg.wait }
        end

        # Stops an asynchronous spinner
        #
        sig { returns(T::Boolean) }
        def stop
          @m.synchronize { @cv.signal }
          @t.value
        end
      end
    end
  end
end
