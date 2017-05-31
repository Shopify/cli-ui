require 'test_helper'

module Dev
  module UI
    class GlyphTest < MiniTest::Test
      def test_glyphs
        assert_equal("\x1b[33m⭑\x1b[0m", Glyph::STAR.to_s)
        assert_equal("\x1b[94m𝒾\x1b[0m", Glyph::INFO.to_s)
        assert_equal("\x1b[94m?\x1b[0m", Glyph::QUESTION.to_s)
        assert_equal("\x1b[32m✓\x1b[0m", Glyph::CHECK.to_s)
        assert_equal("\x1b[31m✗\x1b[0m", Glyph::X.to_s)

        assert_equal(Glyph::STAR,     Glyph.lookup('*'))
        assert_equal(Glyph::INFO,     Glyph.lookup('i'))
        assert_equal(Glyph::QUESTION, Glyph.lookup('?'))
        assert_equal(Glyph::CHECK,    Glyph.lookup('v'))
        assert_equal(Glyph::X,        Glyph.lookup('x'))

        assert_raises(Glyph::InvalidGlyphHandle) do
          Glyph.lookup('$')
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
