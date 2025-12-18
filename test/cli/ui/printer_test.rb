# frozen_string_literal: true

require 'test_helper'

module CLI
  module UI
    class PrinterTest < Minitest::Test
      def test_puts_color
        out, _ = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          assert(Printer.puts('foo', frame_color: :red))
        end

        assert_equal("\e[0mfoo\n", out)
      end

      # NOTE: The spacing in the assertion of this test is important for
      #       downstream projects and should be maintained.
      def test_puts_color_frame
        out = nil
        capture_io do
          Frame.open('test') do
            out, _ = capture_io do
              CLI::UI::StdoutRouter.ensure_activated
              Printer.puts('foo', frame_color: :red)
            end
          end
        end

        assert_equal("\e[31m┃\e[0m \e[0mfoo\n", out)
      end

      def test_frame_with_long_texts
        overlong_preamble = 'a' * (CLI::UI::Terminal.width + 1)
        overlong_suffix = 'z' * (CLI::UI::Terminal.width + 1)

        out = nil
        capture_io do
          Frame.open(overlong_preamble, success_text: overlong_suffix) do
            out, _ = capture_io do
              CLI::UI::StdoutRouter.ensure_activated
              Printer.puts('foo', frame_color: :red)
            end
          end
        end

        assert_equal("\e[31m┃\e[0m \e[0mfoo\n", out)
      end

      def test_puts_stream
        _, err = capture_io do
          assert(Printer.puts('foo', to: $stderr, format: false))
        end

        assert_equal("foo\n", err)
      end

      def test_puts_format
        out, _ = capture_io do
          assert(Printer.puts('{{x}} foo'))
        end

        assert_equal("\e[0;31m✗\e[0m foo\n", out)
      end

      def test_puts_pipe
        IO.pipe do |r, w|
          assert(Printer.puts('foo', to: w, format: false))
          assert_equal("foo\n", r.gets)
        end
      end

      def test_puts_pipe_closed
        IO.pipe do |_r, w|
          w.close
          assert_raises(IOError) do
            Printer.puts('foo', to: w, graceful: false)
          end
        end
      end

      def test_puts_graceful
        IO.pipe do |r, w|
          w.close
          refute(Printer.puts('foo', to: w, graceful: true))
          assert_nil(r.gets)
        end
      end

      def test_encoding
        msg = 'é'.dup.force_encoding(Encoding::ISO_8859_1)
        out, _ = capture_io do
          assert(Printer.puts(msg, encoding: nil, format: false))
        end
        refute_equal(msg + "\n", out) # It doesn't work
        assert_equal(msg.encode(Encoding::UTF_8) + "\n", out)
      end

      def test_encoding_ut8
        msg = 'é'.dup.force_encoding(Encoding::ISO_8859_1)
        out, _ = capture_io do
          assert(Printer.puts(msg, format: false))
        end
        assert_equal(msg + "\n", out)
      end

      def test_write
        out, _ = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          assert(Printer.write('foo', format: false))
          assert(Printer.write(' bar', format: false))
        end

        assert_equal('foo bar', out)
      end

      def test_write_color_frame
        out = nil
        capture_io do
          Frame.open('test') do
            out, _ = capture_io do
              CLI::UI::StdoutRouter.ensure_activated
              Printer.write('foo', frame_color: :red)
              Printer.write(' bar')
            end
          end
        end

        assert_equal("\e[31m┃\e[0m \e[0mfoo\e[0m bar", out)
      end
    end
  end
end
