# typed: true
# frozen_string_literal: true

require 'cli/ui'

module CLI
  module UI
    class Printer
      extend T::Sig

      class << self
        extend T::Sig

        # Print a message to a stream with common utilities.
        # Allows overriding the color, encoding, and target stream.
        # By default, it formats the string using CLI:UI and rescues common stream errors.
        #
        # ==== Attributes
        #
        # * +msg+ - (required) the string to output. Can be frozen.
        #
        # ==== Options
        #
        # * +:frame_color+ - Override the frame color. Defaults to nil.
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with a puts method. Defaults to $stdout.
        # * +:encoding+ - Force the output to be in a certain encoding. Defaults to UTF-8.
        # * +:format+ - Whether to format the string using CLI::UI.fmt. Defaults to true.
        # * +:graceful+ - Whether to gracefully ignore common I/O errors. Defaults to true.
        # * +:wrap+ - Whether to wrap text at word boundaries to terminal width. Defaults to true.
        #
        # ==== Returns
        # Returns whether the message was successfully printed,
        # which can be useful if +:graceful+ is set to true.
        #
        # ==== Example
        #
        #   CLI::UI::Printer.puts('{{x}} Ouch', to: $stderr)
        #
        sig do
          params(
            msg: String,
            frame_color: T.nilable(Colorable),
            to: IOLike,
            encoding: T.nilable(Encoding),
            format: T::Boolean,
            graceful: T::Boolean,
            wrap: T::Boolean,
          ).returns(T::Boolean)
        end
        def puts(
          msg,
          frame_color: nil,
          to: $stdout,
          encoding: Encoding::UTF_8,
          format: true,
          graceful: true,
          wrap: true
        )
          process_message(msg, frame_color, to, encoding, format, wrap, graceful) do |processed_msg|
            to.puts(processed_msg)
          end
        end

        # Write a message to a stream with common utilities without appending a newline.
        # Allows overriding the color, encoding, and target stream.
        # By default, it formats the string using CLI:UI and rescues common stream errors.
        #
        # ==== Attributes
        #
        # * +msg+ - (required) the string to output. Can be frozen.
        #
        # ==== Options
        #
        # * +:frame_color+ - Override the frame color. Defaults to nil.
        # * +:to+ - Target stream, like $stdout or $stderr. Can be anything with a write method. Defaults to $stdout.
        # * +:encoding+ - Force the output to be in a certain encoding. Defaults to UTF-8.
        # * +:format+ - Whether to format the string using CLI::UI.fmt. Defaults to true.
        # * +:graceful+ - Whether to gracefully ignore common I/O errors. Defaults to true.
        # * +:wrap+ - Whether to wrap text at word boundaries to terminal width. Defaults to true.
        #
        # ==== Returns
        # Returns whether the message was successfully printed,
        # which can be useful if +:graceful+ is set to true.
        #
        # ==== Example
        #
        #   CLI::UI::Printer.write('{{x}} Ouch', to: $stderr)
        #
        sig do
          params(
            msg: String,
            frame_color: T.nilable(Colorable),
            to: IOLike,
            encoding: T.nilable(Encoding),
            format: T::Boolean,
            graceful: T::Boolean,
            wrap: T::Boolean,
          ).returns(T::Boolean)
        end
        def write(
          msg,
          frame_color: nil,
          to: $stdout,
          encoding: Encoding::UTF_8,
          format: true,
          graceful: true,
          wrap: true
        )
          process_message(msg, frame_color, to, encoding, format, wrap, graceful) do |processed_msg|
            to.write(processed_msg)
          end
        end

        private

        sig do
          params(
            msg: String,
            frame_color: T.nilable(Colorable),
            to: IOLike,
            encoding: T.nilable(Encoding),
            format: T::Boolean,
            wrap: T::Boolean,
            graceful: T::Boolean,
            block: T.proc.params(arg0: String).void,
          ).returns(T::Boolean)
        end
        def process_message(msg, frame_color, to, encoding, format, wrap, graceful, &block) # rubocop:disable Metrics/ParameterLists
          msg = (+msg).force_encoding(encoding) if encoding
          msg = CLI::UI.fmt(msg) if format
          msg = CLI::UI.wrap(msg) if wrap

          if frame_color
            CLI::UI::Frame.with_frame_color_override(frame_color) { block.call(msg) }
          else
            block.call(msg)
          end

          true
        rescue Errno::EIO, Errno::EPIPE, IOError => e
          raise(e) unless graceful

          false
        end
      end
    end
  end
end
