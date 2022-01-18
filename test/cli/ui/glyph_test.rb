require 'test_helper'

module CLI
  module UI
    class GlyphTest < Minitest::Test
      def test_glyphs
        assert_equal("\x1b[33m⭑\x1b[0m", Glyph::STAR.to_s)
        assert_equal("\x1b[94m𝒾\x1b[0m", Glyph::INFO.to_s)
        assert_equal("\x1b[94m?\x1b[0m", Glyph::QUESTION.to_s)
        assert_equal("\x1b[32m✓\x1b[0m", Glyph::CHECK.to_s)
        assert_equal("\x1b[31m✗\x1b[0m", Glyph::X.to_s)
        assert_equal("\x1b[97m🐛\x1b[0m", Glyph::BUG.to_s)
        assert_equal("\x1b[33m»\x1b[0m", Glyph::CHEVRON.to_s)

        assert_equal(Glyph::STAR,     Glyph.lookup('*'))
        assert_equal(Glyph::INFO,     Glyph.lookup('i'))
        assert_equal(Glyph::QUESTION, Glyph.lookup('?'))
        assert_equal(Glyph::CHECK,    Glyph.lookup('v'))
        assert_equal(Glyph::X,        Glyph.lookup('x'))
        assert_equal(Glyph::BUG,      Glyph.lookup('b'))
        assert_equal(Glyph::CHEVRON,  Glyph.lookup('>'))

        assert_raises(Glyph::InvalidGlyphHandle) do
          Glyph.lookup('$')
        end
      end

      def test_plain_glyphs
        with_os_mock_and_reload(
          CLI::UI::OS::Windows,
          :Glyph,
          File.join(File.dirname(__FILE__), '../../../lib/cli/ui/glyph.rb')
        ) do
          assert_equal("\x1b[33m*\x1b[0m", Glyph::STAR.to_s)
          assert_equal("\x1b[94mi\x1b[0m", Glyph::INFO.to_s)
          assert_equal("\x1b[94m?\x1b[0m", Glyph::QUESTION.to_s)
          assert_equal("\x1b[32m√\x1b[0m", Glyph::CHECK.to_s)
          assert_equal("\x1b[31mX\x1b[0m", Glyph::X.to_s)
          assert_equal("\x1b[97m!\x1b[0m", Glyph::BUG.to_s)
          assert_equal("\x1b[33m»\x1b[0m", Glyph::CHEVRON.to_s)

          assert_equal(Glyph::STAR,     Glyph.lookup('*'))
          assert_equal(Glyph::INFO,     Glyph.lookup('i'))
          assert_equal(Glyph::QUESTION, Glyph.lookup('?'))
          assert_equal(Glyph::CHECK,    Glyph.lookup('v'))
          assert_equal(Glyph::X,        Glyph.lookup('x'))
          assert_equal(Glyph::BUG,      Glyph.lookup('b'))
          assert_equal(Glyph::CHEVRON,  Glyph.lookup('>'))

          assert_raises(Glyph::InvalidGlyphHandle) do
            Glyph.lookup('$')
          end
        end
      end

      def test_useful_exception
        e = begin
          Glyph.lookup('$')
        rescue => e
          e
        end
        assert_match(/invalid glyph handle: \$/, e.message) # error
        assert_match(/Glyph\.available/, e.message) # where to find colors
        assert_match(/\*/, e.message) # list of valid colors
      end
    end
  end
end
