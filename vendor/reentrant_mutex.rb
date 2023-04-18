# Copyright (c) 2014 Boris Bera
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Sourced from https://github.com/dotboris/reentrant_mutex
module CLI
  module UI
    class ReentrantMutex < Mutex
      def initialize
        @count_mutex = Mutex.new
        @counts = Hash.new(0)

        super
      end

      def synchronize
        raise ThreadError, 'Must be called with a block' unless block_given?

        begin
          lock
          yield
        ensure
          unlock
        end
      end

      def lock
        c = increase_count Thread.current
        super if c <= 1
      end

      def unlock
        c = decrease_count Thread.current
        if c <= 0
          super
          delete_count Thread.current
        end
      end

      def count
        @count_mutex.synchronize { @counts[Thread.current] }
      end

      private

      def increase_count(thread)
        @count_mutex.synchronize { @counts[thread] += 1 }
      end

      def decrease_count(thread)
        @count_mutex.synchronize { @counts[thread] -= 1 }
      end

      def delete_count(thread)
        @count_mutex.synchronize { @counts.delete(thread) }
      end
    end
  end
end
