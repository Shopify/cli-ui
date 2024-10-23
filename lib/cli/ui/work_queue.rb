# typed: strict
# frozen_string_literal: true

module CLI
  module UI
    class WorkQueue
      extend T::Sig

      class Future
        extend T::Sig

        sig { returns(T.nilable(Thread)) }
        attr_accessor :worker_thread

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

        sig { void }
        def interrupt
          @mutex.synchronize do
            if @started && !@completed
              @worker_thread&.raise(Interrupt)
            elsif !@started
              @completed = true
              @error = Interrupt.new
              @condition.broadcast
            end
          end
        end
      end

      sig { params(max_concurrent: Integer).void }
      def initialize(max_concurrent)
        @max_concurrent = max_concurrent
        @queue = T.let(Queue.new, Queue)
        @running = T.let(0, Integer)
        @mutex = T.let(Mutex.new, Mutex)
        @condition = T.let(ConditionVariable.new, ConditionVariable)
        @workers = T.let([], T::Array[Thread])
        @futures = T.let([], T::Array[Future])
        start_workers
      end

      sig { params(block: T.proc.returns(T.untyped)).returns(Future) }
      def enqueue(&block)
        future = Future.new
        @mutex.synchronize do
          @futures << future
        end
        @queue.push([future, block])
        future
      end

      sig { void }
      def wait
        @queue.close
        @workers.each(&:join)
      end

      sig { void }
      def interrupt
        @mutex.synchronize do
          @queue.clear
          @futures.each(&:interrupt)
          @workers.each { |worker| worker.raise(Interrupt) }
          @workers.clear
          @futures.clear
        end
      end

      private

      sig { void }
      def start_workers
        @max_concurrent.times do
          @workers << Thread.new do
            loop do
              work = @queue.pop
              break if work.nil?

              future, block = work

              @mutex.synchronize do
                @condition.wait(@mutex) while @running >= @max_concurrent
                @running += 1
              end

              begin
                future.worker_thread = Thread.current
                future.start
                result = block.call
                future.complete(result)
              rescue StandardError => e
                future.fail(e)
              ensure
                future.worker_thread = nil
                @mutex.synchronize do
                  @running -= 1
                  @condition.signal
                  @futures.delete(future)
                end
              end
            end
          end
        end
      end
    end
  end
end
