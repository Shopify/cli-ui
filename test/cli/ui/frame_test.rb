require 'test_helper'

module CLI
  module UI
    class FrameTest < MiniTest::Test
      def test_text_in_frame
        out, _ = capture_io do
          CLI::UI::StdoutRouter.ensure_activated
          CLI::UI.frame('foo', color: :yellow) do
            CLI::UI.puts('bar')
          end
        end

        assert_equal("\e[33m┃ \e[0m\e[0mbar", out.lines[1].chomp)
      end
    end
  end
end
