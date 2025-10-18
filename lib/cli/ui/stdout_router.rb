# typed: true
# frozen_string_literal: true

require 'stringio'
require_relative '../../../vendor/reentrant_mutex'

module CLI
  module UI
    module StdoutRouter
      class Writer
        #: (io_like stream, Symbol name) -> void
        def initialize(stream, name)
          @stream = stream
          @name = name
        end

        #: (*Object args) -> Integer
        def write(*args)
          strs = args.map do |obj|
            str = obj.to_s
            if auto_frame_inset?
              str = str.dup # unfreeze
              str = str.to_s.force_encoding(Encoding::UTF_8)
              apply_line_prefix(str, CLI::UI::Frame.prefix)
            else
              @pending_newline = false
              str
            end
          end

          # hook return of false suppresses output.
          if (hook = Thread.current[:cliui_output_hook])
            return 0 if hook.call(strs.join, @name) == false
          end

          stream_args = prepend_id(@stream, strs) #: as untyped
          ret = @stream.write_without_cli_ui(*stream_args) #: as Integer
          if (dup = StdoutRouter.duplicate_output_to)
            begin
              dup_args = prepend_id(dup, strs) #: as untyped
              dup.write(*dup_args) #: as Integer
            rescue IOError
              # Ignore
            end
          end
          ret
        end

        private

        #: (io_like stream, Array[String] args) -> Array[String]
        def prepend_id(stream, args)
          return args unless prepend_id_for_stream(stream)

          args.map do |a|
            next a if a.chomp.empty? # allow new lines to be new lines

            "[#{Thread.current[:cliui_output_id][:id]}] #{a}"
          end
        end

        #: (io_like stream) -> bool
        def prepend_id_for_stream(stream)
          return false unless Thread.current[:cliui_output_id]
          return true if Thread.current[:cliui_output_id][:streams].include?(stream)

          false
        end

        #: -> bool
        def auto_frame_inset?
          !Thread.current[:no_cliui_frame_inset]
        end

        #: (String str, String prefix) -> String
        def apply_line_prefix(str, prefix)
          return '' if str.empty?

          prefixed = +''
          str.force_encoding(Encoding::UTF_8).lines.each do |line|
            if @pending_newline
              prefixed << line
              @pending_newline = false
            else
              prefixed << prefix << line
            end
          end
          @pending_newline = !str.end_with?("\n")
          prefixed
        end
      end

      class Capture
        @capture_mutex = Mutex.new
        @stdin_mutex = CLI::UI::ReentrantMutex.new
        @active_captures = 0
        @saved_stdin = nil

        class << self
          #: -> Capture?
          def current_capture
            Thread.current[:cliui_current_capture]
          end

          #: -> Capture
          def current_capture!
            current_capture #: as !nil
          end

          #: [T] { -> T } -> T
          def in_alternate_screen(&block)
            stdin_synchronize do
              previous_print_captured_output = current_capture&.print_captured_output
              current_capture&.print_captured_output = true
              Spinner::SpinGroup.pause_spinners do
                if outermost_uncaptured?
                  begin
                    prev_hook = Thread.current[:cliui_output_hook]
                    Thread.current[:cliui_output_hook] = nil
                    replay = current_capture!.stdout.gsub(ANSI.match_alternate_screen, '')
                    CLI::UI.raw do
                      print("#{ANSI.enter_alternate_screen}#{replay}")
                    end
                  ensure
                    Thread.current[:cliui_output_hook] = prev_hook
                  end
                end
                block.call
              ensure
                print(ANSI.exit_alternate_screen) if outermost_uncaptured?
              end
            ensure
              current_capture&.print_captured_output = !!previous_print_captured_output
            end
          end

          #: [T] { -> T } -> T
          def stdin_synchronize(&block)
            @stdin_mutex.synchronize do
              case $stdin
              when BlockingInput
                $stdin.synchronize do
                  block.call
                end
              else
                block.call
              end
            end
          end

          #: [T] { -> T } -> T
          def with_stdin_masked(&block)
            @capture_mutex.synchronize do
              if @active_captures.zero?
                @stdin_mutex.synchronize do
                  @saved_stdin = $stdin
                  $stdin = BlockingInput.new(@saved_stdin)
                end
              end
              @active_captures += 1
            end

            yield
          ensure
            @capture_mutex.synchronize do
              @active_captures -= 1
              if @active_captures.zero?
                @stdin_mutex.synchronize do
                  $stdin = @saved_stdin
                end
              end
            end
          end

          private

          #: -> bool
          def outermost_uncaptured?
            @stdin_mutex.count == 1 && $stdin.is_a?(BlockingInput)
          end
        end

        #: (?with_frame_inset: bool, ?merged_output: bool, ?duplicate_output_to: IO) { -> void } -> void
        def initialize(
          with_frame_inset: true,
          merged_output: false,
          duplicate_output_to: File.open(File::NULL, 'w'),
          &block
        )
          @with_frame_inset = with_frame_inset
          @merged_output = merged_output
          @duplicate_output_to = duplicate_output_to
          @block = block
          @print_captured_output = false
          @out = StringIO.new
          @err = StringIO.new
        end

        #: bool
        attr_accessor :print_captured_output

        #: -> untyped
        def run
          require 'stringio'

          StdoutRouter.assert_enabled!

          Thread.current[:cliui_current_capture] = self

          prev_frame_inset = Thread.current[:no_cliui_frame_inset]
          prev_hook = Thread.current[:cliui_output_hook]

          if Thread.current.respond_to?(:report_on_exception)
            Thread.current.report_on_exception = false
          end

          self.class.with_stdin_masked do
            Thread.current[:no_cliui_frame_inset] = !@with_frame_inset
            Thread.current[:cliui_output_hook] = ->(data, stream) do
              stream = :stdout if @merged_output
              case stream
              when :stdout
                @out.write(data)
                @duplicate_output_to.write(data)
              when :stderr
                @err.write(data)
              else raise
              end
              print_captured_output # suppress writing to terminal by default
            end

            @block.call
          end
        ensure
          Thread.current[:cliui_output_hook] = prev_hook
          Thread.current[:no_cliui_frame_inset] = prev_frame_inset
          Thread.current[:cliui_current_capture] = nil
        end

        #: -> String
        def stdout
          @out.string
        end

        #: -> String
        def stderr
          @err.string
        end

        class BlockingInput
          #: (IO stream) -> void
          def initialize(stream)
            @stream = stream
            @m = CLI::UI::ReentrantMutex.new
          end

          #: [T] { -> T } -> T
          def synchronize(&block)
            @m.synchronize do
              previous_allowed_to_read = Thread.current[:cliui_allowed_to_read]
              Thread.current[:cliui_allowed_to_read] = true
              block.call
            ensure
              Thread.current[:cliui_allowed_to_read] = previous_allowed_to_read
            end
          end

          READING_METHODS = [
            :each,
            :each_byte,
            :each_char,
            :each_codepoint,
            :each_line,
            :getbyte,
            :getc,
            :getch,
            :gets,
            :read,
            :read_nonblock,
            :readbyte,
            :readchar,
            :readline,
            :readlines,
            :readpartial,
          ]

          NON_READING_METHODS = IO.instance_methods(false) - READING_METHODS

          READING_METHODS.each do |method|
            define_method(method) do |*args, **kwargs, &block|
              raise(IOError, 'closed stream') unless Thread.current[:cliui_allowed_to_read]

              @stream.send(method, *args, **kwargs, &block)
            end
          end

          NON_READING_METHODS.each do |method|
            define_method(method) do |*args, **kwargs, &block|
              @stream.send(method, *args, **kwargs, &block)
            end
          end
        end
      end

      class << self
        WRITE_WITHOUT_CLI_UI = :write_without_cli_ui

        NotEnabled = Class.new(StandardError)

        #: io_like?
        attr_accessor :duplicate_output_to

        #: [T] (on_streams: Array[io_like]) { (String id) -> T } -> T
        def with_id(on_streams:, &block)
          require 'securerandom'
          id = format('%05d', rand(10**5))
          Thread.current[:cliui_output_id] = {
            id: id,
            streams: on_streams.map do |stream|
              stream #: as io_like
            end,
          }
          yield(id)
        ensure
          Thread.current[:cliui_output_id] = nil
        end

        #: -> Hash[Symbol, (String | io_like)]?
        def current_id
          Thread.current[:cliui_output_id]
        end

        #: -> void
        def assert_enabled!
          raise NotEnabled unless enabled?
        end

        #: [T] { -> T } -> T
        def with_enabled(&block)
          enable
          yield
        ensure
          disable
        end

        # TODO: remove this
        #: -> void
        def ensure_activated
          enable unless enabled?
        end

        #: -> bool
        def enable
          return false if enabled?($stdout) || enabled?($stderr)

          activate($stdout, :stdout)
          activate($stderr, :stderr)
          true
        end

        #: (?io_like stream) -> bool
        def enabled?(stream = $stdout)
          stream.respond_to?(WRITE_WITHOUT_CLI_UI)
        end

        #: -> bool
        def disable
          return false unless enabled?($stdout) && enabled?($stderr)

          deactivate($stdout)
          deactivate($stderr)
          true
        end

        private

        #: (io_like stream) -> void
        def deactivate(stream)
          sc = stream.singleton_class
          sc.send(:remove_method, :write)
          sc.send(:alias_method, :write, WRITE_WITHOUT_CLI_UI)
        end

        #: (io_like stream, Symbol streamname) -> void
        def activate(stream, streamname)
          writer = StdoutRouter::Writer.new(stream, streamname)

          raise if stream.respond_to?(WRITE_WITHOUT_CLI_UI)

          stream.singleton_class.send(:alias_method, WRITE_WITHOUT_CLI_UI, :write)
          stream.define_singleton_method(:write) do |*args|
            writer.write(*args)
          end
        end
      end
    end
  end
end
