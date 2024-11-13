# typed: strict
# frozen_string_literal: true

module CLI
  module UI
    class WorkQueue
      extend T::Sig

      class Future
        extend T::Sig

        sig { void }
        def initialize
          @mutex = T.let(Mutex.new, Mutex)
          @condition = T.let(ConditionVariable.new, ConditionVariable)
          @completed = T.let(false, T::Boolean)
          @started = T.let(false, T::Boolean)
          @result = T.let(nil, T.untyped)
          @error = T.let(nil, T.nilable(Exception))
        end

        sig { params(result: T.untyped).void }
        def complete(result)
          @mutex.synchronize do
            @completed = true
            @result = result
            @condition.broadcast
          end
        end

        sig { params(error: Exception).void }
        def fail(error)
          @mutex.synchronize do
            return if @completed

            @completed = true
            @error = error
            @condition.broadcast
          end
        end

        sig { returns(T.untyped) }
        def value
          @mutex.synchronize do
            @condition.wait(@mutex) until @completed
            raise @error if @error

            @result
          end
        end

        sig { returns(T::Boolean) }
        def completed?
          @mutex.synchronize { @completed }
        end

        sig { returns(T::Boolean) }
        def started?
          @mutex.synchronize { @started }
        end

        sig { void }
        def start
          @mutex.synchronize do
            @started = true
            @condition.broadcast
          end
        end
      end

      sig { params(max_concurrent: Integer).void }
      def initialize(max_concurrent)
        @max_concurrent = max_concurrent
        @queue = T.let(Queue.new, Queue)
        @mutex = T.let(Mutex.new, Mutex)
        @condition = T.let(ConditionVariable.new, ConditionVariable)
        @workers = T.let([], T::Array[Thread])
      end

      sig { params(block: T.proc.returns(T.untyped)).returns(Future) }
      def enqueue(&block)
        future = Future.new
        @mutex.synchronize do
          start_worker if @workers.size < @max_concurrent
        end
        @queue.push([future, block])
        future
      end

      sig { void }
      def close
        @queue.close
      end

      sig { void }
      def wait
        @queue.close
        @workers.each(&:join)
      end

      sig { void }
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

      sig { void }
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
