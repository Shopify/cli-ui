# typed: true
require 'cli/ui'
require 'stringio'

module CLI
  module UI
    module StdoutRouter
      class Writer
        extend T::Sig

        sig { params(stream: IOLike, name: Symbol).void }
        def initialize(stream, name)
          @stream = stream
          @name = name
        end

        sig { params(args: String).void }
        def write(*args)
          args = args.map do |str|
            if auto_frame_inset?
              str = str.dup # unfreeze
              str = str.force_encoding(Encoding::UTF_8)
              apply_line_prefix(str, CLI::UI::Frame.prefix)
            else
              @pending_newline = false
              str
            end
          end

          # hook return of false suppresses output.
          if (hook = Thread.current[:cliui_output_hook])
            return if hook.call(args.map(&:to_s).join, @name) == false
          end

          T.unsafe(@stream).write_without_cli_ui(*prepend_id(@stream, args))
          if (dup = StdoutRouter.duplicate_output_to)
            T.unsafe(dup).write(*prepend_id(dup, args))
          end
        end

        private

        sig { params(stream: IOLike, args: T::Array[String]).returns(T::Array[String]) }
        def prepend_id(stream, args)
          return args unless prepend_id_for_stream(stream)

          args.map do |a|
            next a if a.chomp.empty? # allow new lines to be new lines

            "[#{Thread.current[:cliui_output_id][:id]}] #{a}"
          end
        end

        sig { params(stream: IOLike).returns(T::Boolean) }
        def prepend_id_for_stream(stream)
          return false unless Thread.current[:cliui_output_id]
          return true if Thread.current[:cliui_output_id][:streams].include?(stream)

          false
        end

        sig { returns(T::Boolean) }
        def auto_frame_inset?
          !Thread.current[:no_cliui_frame_inset]
        end

        sig { params(str: String, prefix: String).returns(String) }
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
        extend T::Sig

        @m = Mutex.new
        @active_captures = 0
        @saved_stdin = nil

        sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
        def self.with_stdin_masked(&block)
          @m.synchronize do
            if @active_captures.zero?
              @saved_stdin = $stdin
              $stdin, w = IO.pipe
              $stdin.close
              w.close
            end
            @active_captures += 1
          end

          yield
        ensure
          @m.synchronize do
            @active_captures -= 1
            if @active_captures.zero?
              $stdin = @saved_stdin
            end
          end
        end

        sig do
          params(with_frame_inset: T::Boolean, block: T.proc.void).void
        end
        def initialize(with_frame_inset: true, &block)
          @with_frame_inset = with_frame_inset
          @block = block
          @stdout = ''
          @stderr = ''
        end

        sig { returns(String) }
        attr_reader :stdout, :stderr

        sig { returns(T.untyped) }
        def run
          require 'stringio'

          StdoutRouter.assert_enabled!

          out = StringIO.new
          err = StringIO.new

          prev_frame_inset = Thread.current[:no_cliui_frame_inset]
          prev_hook = Thread.current[:cliui_output_hook]

          if Thread.current.respond_to?(:report_on_exception)
            Thread.current.report_on_exception = false
          end

          self.class.with_stdin_masked do
            Thread.current[:no_cliui_frame_inset] = !@with_frame_inset
            Thread.current[:cliui_output_hook] = ->(data, stream) do
              case stream
              when :stdout then out.write(data)
              when :stderr then err.write(data)
              else raise
              end
              false # suppress writing to terminal
            end

            begin
              @block.call
            ensure
              @stdout = out.string
              @stderr = err.string
            end
          end
        ensure
          Thread.current[:cliui_output_hook] = prev_hook
          Thread.current[:no_cliui_frame_inset] = prev_frame_inset
        end
      end

      class << self
        extend T::Sig

        WRITE_WITHOUT_CLI_UI = :write_without_cli_ui

        NotEnabled = Class.new(StandardError)

        sig { returns(T.nilable(IOLike)) }
        attr_accessor :duplicate_output_to

        sig do
          type_parameters(:T)
            .params(on_streams: T::Array[IOLike], block: T.proc.params(id: String).returns(T.type_parameter(:T)))
            .returns(T.type_parameter(:T))
        end
        def with_id(on_streams:, &block)
          require 'securerandom'
          id = format('%05d', rand(10**5))
          Thread.current[:cliui_output_id] = {
            id: id,
            streams: on_streams.map { |stream| T.cast(stream, IOLike) },
          }
          yield(id)
        ensure
          Thread.current[:cliui_output_id] = nil
        end

        sig { returns(T.nilable(T::Hash[Symbol, T.any(String, IOLike)])) }
        def current_id
          Thread.current[:cliui_output_id]
        end

        sig { void }
        def assert_enabled!
          raise NotEnabled unless enabled?
        end

        sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
        def with_enabled(&block)
          enable
          yield
        ensure
          disable
        end

        # TODO: remove this
        sig { void }
        def ensure_activated
          enable unless enabled?
        end

        sig { returns(T::Boolean) }
        def enable
          return false if enabled?($stdout) || enabled?($stderr)

          activate($stdout, :stdout)
          activate($stderr, :stderr)
          true
        end

        sig { params(stream: IOLike).returns(T::Boolean) }
        def enabled?(stream = $stdout)
          stream.respond_to?(WRITE_WITHOUT_CLI_UI)
        end

        sig { returns(T::Boolean) }
        def disable
          return false unless enabled?($stdout) && enabled?($stderr)

          deactivate($stdout)
          deactivate($stderr)
          true
        end

        private

        sig { params(stream: IOLike).void }
        def deactivate(stream)
          sc = stream.singleton_class
          sc.send(:remove_method, :write)
          sc.send(:alias_method, :write, WRITE_WITHOUT_CLI_UI)
        end

        sig { params(stream: IOLike, streamname: Symbol).void }
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
