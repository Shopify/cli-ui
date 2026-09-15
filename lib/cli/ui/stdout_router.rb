# typed: true
# frozen_string_literal: true

require 'stringio'
# Required eagerly because `BlockingInput` snapshots`IO.instance_methods` at
# class-load; `io/console` must have grafted its terminal-mode methods (noecho,
# raw, ...) onto IO by then so they get delegated to the wrapped stream.
require 'io/console'
require_relative '../../../vendor/reentrant_mutex'

module CLI
  module UI
    module StdoutRouter
      WRITE_WITHOUT_CLI_UI = :write_without_cli_ui
      COMPATIBILITY_WRITE_IVAR = :@__cli_ui_stdout_router_compatibility_write
      private_constant :COMPATIBILITY_WRITE_IVAR

      # Defined here rather than on the singleton class, where callers had no
      # way to name it.
      NotEnabled = Class.new(StandardError)

      class CompatibilityWrite
        #: Method
        attr_reader :installed_method

        #: Method
        attr_reader :original_write

        #: (Method installed_method, Method original_write) -> void
        def initialize(installed_method, original_write)
          @installed_method = installed_method
          @original_write = original_write
        end
      end
      private_constant :CompatibilityWrite

      class Writer
        #: Method
        attr_reader :original_write

        # `original_write` must be the stream's pre-routing `write`; it is
        # required because resolving it from an already-routed stream would
        # stack a second Writer on the first. Holding the method itself keeps
        # an in-flight write working after `deactivate`.
        #: (io_like stream, Symbol name, Method original_write) -> void
        def initialize(stream, name, original_write)
          @stream = stream
          @name = name
          @original_write = original_write
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
          ret = @original_write.call(*stream_args) #: as Integer
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

          StdoutRouter.with_enabled do
            prev_frame_inset = Thread.current[:no_cliui_frame_inset]
            prev_hook = Thread.current[:cliui_output_hook]
            Thread.current[:cliui_current_capture] = self

            begin
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
          end
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
          raise NotEnabled unless current_streams.all? { |stream,| routed?(stream) }
        end

        # Routes only streams not already routed by this module, then unroutes
        # only those streams when the scope exits.
        #: [T] { -> T } -> T
        def with_enabled(&block)
          activated = activate_current_streams
          yield
        ensure
          activated&.reverse_each { |stream| deactivate(stream) }
        end

        # TODO: remove this
        #: -> void
        def ensure_activated
          enable
        end

        # Routes the current $stdout/$stderr; returns whether anything changed.
        # Additive and per-stream so a half-routed process can recover without
        # unrouting a stream that was only replaced in the globals temporarily.
        #: -> bool
        def enable
          !activate_current_streams.empty?
        end

        #: (?io_like stream) -> bool
        def routed?(stream = $stdout)
          !route_writers[stream].nil?
        end

        # Kept for compatibility. `routed?` names the membership check more
        # precisely.
        #: (?io_like stream) -> bool
        def enabled?(stream = $stdout)
          routed?(stream)
        end

        # Returns a snapshot so callers can inspect routing without gaining
        # access to the mutable registry or its Writer values.
        #: -> Array[io_like]
        def routed_streams
          streams = [] #: Array[io_like]
          route_writers.each_key do |stream|
            streams << stream if routed?(stream)
          end
          streams
        end

        # Unroutes `stream`, or every routed stream when none is given; returns
        # whether anything changed.
        #: (?io_like? stream) -> bool
        def disable(stream = nil)
          routed = stream.nil? ? routed_streams : [stream].select { |candidate| routed?(candidate) }
          routed.each { |routed_stream| deactivate(routed_stream) }
          !routed.empty?
        end

        # Writes past the router: no frame inset, capture hooks, or output
        # duplication. Prefer this to calling WRITE_WITHOUT_CLI_UI directly,
        # which exists only after a stream has been routed at least once.
        #: (io_like stream, *Object args) -> Integer
        def write_without_routing(stream, *args)
          compatibility_write = owned_compatibility_write(stream)
          original_write = compatibility_write&.original_write || route_writers[stream]&.original_write
          write_args = args #: as untyped
          return stream.write(*write_args) unless original_write

          original_write.call(*write_args) #: as Integer
        end

        private

        # Weak keys let a caller-owned stream and its routing wrapper disappear
        # together if the caller drops the stream without explicitly disabling
        # it. Ruby 3.2's WeakMap has no `delete`, so deactivation tombstones the
        # value; public readers filter those entries.
        #: -> untyped
        def route_writers
          @route_writers ||= ObjectSpace::WeakMap.new
        end

        #: -> Hash[io_like, Symbol]
        def current_streams
          streams = {}.compare_by_identity #: Hash[io_like, Symbol]
          streams[$stdout] = :stdout
          streams[$stderr] = :stderr unless streams.key?($stderr)
          streams
        end

        #: (Hash[io_like, Symbol] streams) -> Array[io_like]
        def activate_streams(streams)
          streams_to_activate = streams.reject { |stream,| routed?(stream) }
          return [] unless streams_to_activate.all? { |stream,| compatibility_write_available?(stream) }

          activated = [] #: Array[io_like]
          begin
            streams_to_activate.each do |stream, streamname|
              activate(stream, streamname)
              activated << stream
            end
            activated
          rescue
            activated.reverse_each { |stream| deactivate(stream) }
            raise
          end
        end

        #: -> Array[io_like]
        def activate_current_streams
          activate_streams(current_streams)
        end

        #: (io_like stream) -> bool
        def compatibility_write_available?(stream)
          !stream.respond_to?(WRITE_WITHOUT_CLI_UI, true) || !owned_compatibility_write(stream).nil?
        end

        #: (io_like stream) -> void
        def deactivate(stream)
          original_write = route_writers[stream]&.original_write
          return unless original_write

          sc = stream.singleton_class

          sc.send(:remove_method, :write)
          # Restore only a `write` we displaced; a stream that inherited its
          # `write` gets the class method back.
          sc.send(:define_method, :write, original_write) if original_write&.owner == sc
          route_writers[stream] = nil
        end

        #: (io_like stream, Symbol streamname) -> void
        def activate(stream, streamname)
          original_write = stream.method(:write)
          writer = StdoutRouter::Writer.new(stream, streamname, original_write)

          install_compatibility_write(stream, original_write)
          stream.define_singleton_method(:write) do |*args|
            writer.write(*args)
          end
          route_writers[stream] = writer
        end

        # The supported bypass is `write_without_routing`; this is the same
        # thing under the name out-of-tree callers already reach for. Closing
        # over the pre-routing method keeps it a bypass after disable, even if
        # a later `write` wrapper calls the compatibility method itself.
        #: (io_like stream, Method original_write) -> void
        def install_compatibility_write(stream, original_write)
          return if owned_compatibility_write(stream)

          stream.singleton_class.send(:define_method, WRITE_WITHOUT_CLI_UI) do |*args|
            write_args = args #: as untyped
            original_write.call(*write_args)
          end
          installed_method = stream.method(WRITE_WITHOUT_CLI_UI)
          compatibility_write = CompatibilityWrite.new(installed_method, original_write)
          stream.instance_variable_set(COMPATIBILITY_WRITE_IVAR, compatibility_write)
        end

        #: (io_like stream) -> CompatibilityWrite?
        def owned_compatibility_write(stream)
          compatibility_write = stream.instance_variable_get(COMPATIBILITY_WRITE_IVAR)
          return unless compatibility_write.is_a?(CompatibilityWrite)
          return unless stream.respond_to?(WRITE_WITHOUT_CLI_UI, true)
          return unless stream.method(WRITE_WITHOUT_CLI_UI) == compatibility_write.installed_method

          compatibility_write
        end
      end
    end
  end
end
