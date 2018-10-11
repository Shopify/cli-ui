require 'test_helper'

module CLI
  module UI
    class FrameTest < MiniTest::Test
      def setup
        CLI::UI::Terminal.stubs(:width).returns(30)
      end

      MACOS_EXPECT = <<~OUT.freeze
        \e[?25l\r\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[1G\e[36m┏━━ \e[0;36mtest\e[0m \e[36m\e[29G\e[0m\e[?25h
        \e[?25l\r\e[36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[1G\e[36m┗━━\e[36m\e[21G (0.0s) \e[0m\e[?25h
      OUT

      BUILDKITE_EXPECT = <<~OUT.freeze
        \e[36m┏━━ \e[0;36mtest\e[0m \e[36m━━━━━━━━━━━━━━━━━━━\e[36m━━\x1b[0m
        \e[36m┗━━\e[36m━━━━━━━━━━━━━━━━━ (0.0s) \e[36m━━\x1b[0m
      OUT

      PIPE_EXPECT = <<~OUT.freeze
        ┏━━ test ━━━━━━━━━━━━━━━━━━━━━
        ┗━━━━━━━━━━━━━━━━━━━ (0.0s) ━━
      OUT

      SIMPLE_FRAME = ->() { Frame.open('test') {} }

      def test_macos
        out = capture(Frame::MacOSTerminalEdgeRenderer, &SIMPLE_FRAME)
        assert_equal(MACOS_EXPECT, out)
      end

      def test_buildkite
        out = capture(Frame::BuildkiteEdgeRenderer, &SIMPLE_FRAME)
        assert_equal(BUILDKITE_EXPECT, out)
      end

      def test_pipe
        out = capture(Frame::PipeEdgeRenderer) { without_color(&SIMPLE_FRAME) }
        assert_equal(PIPE_EXPECT, out)
      end

      private

      def capture(edge_renderer)
        prev = Frame.edge_renderer
        Frame.edge_renderer = edge_renderer
        out, _ = capture_io do
          StdoutRouter.with_enabled do
            yield
          end
        end
        out
      ensure
        Frame.edge_renderer = prev
      end

      def without_color
        CLI::UI.enable_color = false
        yield
      ensure
        CLI::UI.enable_color = true
      end
    end
  end
end
