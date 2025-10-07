# typed: strict
# frozen_string_literal: true

module CLI
  module UI
    class WorkQueue
      class Future
        #: -> void
        def initialize
          @mutex = Mutex.new #: Mutex
          @condition = ConditionVariable.new #: ConditionVariable
          @completed = false #: bool
          @started = false #: bool
          @result = nil #: untyped
          @error = nil #: Exception?
        end

        #: (untyped result) -> void
        def complete(result)
          @mutex.synchronize do
            @completed = true
            @result = result
            @condition.broadcast
          end
        end

        #: (Exception error) -> void
        def fail(error)
          @mutex.synchronize do
            return if @completed

            @completed = true
            @error = error
            @condition.broadcast
          end
        end

        #: -> untyped
        def value
          @mutex.synchronize do
            @condition.wait(@mutex) until @completed
            raise @error if @error

            @result
          end
        end

        #: -> bool
        def completed?
          @mutex.synchronize { @completed }
        end

        #: -> bool
        def started?
          @mutex.synchronize { @started }
        end

        #: -> void
        def start
          @mutex.synchronize do
            @started = true
            @condition.broadcast
          end
        end
      end

      #: (Integer max_concurrent) -> void
      def initialize(max_concurrent)
        @max_concurrent = max_concurrent
        @queue = Queue.new #: Queue
        @mutex = Mutex.new #: Mutex
        @condition = ConditionVariable.new #: ConditionVariable
        @workers = [] #: Array[Thread]
      end

      #: { -> untyped } -> Future
      def enqueue(&block)
        future = Future.new
        @mutex.synchronize do
          start_worker if @workers.size < @max_concurrent
        end
        @queue.push([future, block])
        future
      end

      #: -> void
      def close
        @queue.close
      end

      #: -> void
      def wait
        @queue.close
        @workers.each(&:join)
      end

      #: -> void
      def interrupt
        @mutex.synchronize do
          @queue.close
          # Fail any remaining tasks in the queue
          until @queue.empty?
            future, _block = @queue.pop(true)
            future&.fail(Interrupt.new)
          end
          # Interrupt all worker threads
          @workers.each { |worker| worker.raise(Interrupt) if worker.alive? }
          @workers.each(&:join)
          @workers.clear
        end
      end

      private

      #: -> void
      def start_worker
        @workers << Thread.new do
          loop do
            work = @queue.pop
            break if work.nil?

            future, block = work

            begin
              future.start
              result = block.call
              future.complete(result)
            rescue Interrupt => e
              future.fail(e)
              raise # Always re-raise interrupts to terminate the worker
            rescue StandardError => e
              future.fail(e)
              # Don't re-raise standard errors - allow worker to continue
            end
          end
        rescue Interrupt
          # Clean exit on interrupt
        end
      end
    end
  end
end
