require 'test_helper'

module CLI
  module UI
    class PrinterTest < MiniTest::Test
      def test_puts_color
        out, _ = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          Printer.puts('foo', frame_color: :red)
        end

        assert_equal("\e[0mfoo\n", out)
      end

      def test_puts_color_frame
        Frame.open('test') do
          out, _ = capture_io do
            CLI::UI::StdoutRouter.ensure_activated
            Printer.puts('foo', frame_color: :red)
          end

          assert_equal("\e[31m┃ \e[0m\e[0mfoo\n", out)
        end
      end

      def test_puts_stream
        _, err = capture_io do
          Printer.puts('foo', stream: $stderr, format: false)
        end

        assert_equal("foo\n", err)
      end

      def test_puts_format
        out, _ = capture_io do
          Printer.puts('{{x}} foo')
        end

        assert_equal("\e[0;31m✗\e[0m foo\n", out)
      end

      def test_puts_pipe
        IO.pipe do |r, w|
          Printer.puts('foo', stream: w, format: false)
          assert_equal("foo\n", r.gets)
        end
      end

      def test_puts_pipe_closed
        IO.pipe do |r, w|
          w.close
          assert_raises(IOError) do
            Printer.puts('foo', stream: w, graceful: false)
          end
        end
      end

      def test_puts_graceful
        IO.pipe do |r, w|
          w.close
          Printer.puts('foo', stream: w, graceful: true)
          assert_nil(r.gets)
        end
      end

      def test_encoding
        msg = "é".force_encoding(Encoding::ISO_8859_1)
        out, _ = capture_io do
          Printer.puts(msg, encoding: nil, format: false)
        end
        refute_equal(msg + "\n", out) # It doesn't work
        assert_equal(msg.encode(Encoding::UTF_8) + "\n", out)
      end

      def test_encoding_ut8
        msg = "é".force_encoding(Encoding::ISO_8859_1)
        out, _ = capture_io do
          Printer.puts(msg, format: false)
        end
        assert_equal(msg + "\n", out)
      end
    end
  end
end
