// xterm.js oracle for the ANSI replay fixtures.
//
// Feeds a capture to xterm.js headless and prints the text its buffer
// settled on, which `bundle exec rake replay:bless` writes to the matching
// .expected file. See README.md.
//
//   npm ci
//   node oracle.js <capture.raw>

const { Terminal } = require('@xterm/headless');
const { UnicodeGraphemesAddon } = require('@xterm/addon-unicode-graphemes');
const fs = require('fs');

// convertEol matches the tty driver's ONLCR, which a capture records without.
// The screen is large enough that fixtures neither wrap nor scroll.
function settle(data, cols, rows) {
  return new Promise((resolve) => {
    const term = new Terminal({ cols, rows, scrollback: 100000, convertEol: true, allowProposedApi: true });
    term.loadAddon(new UnicodeGraphemesAddon());
    term.unicode.activeVersion = '15-graphemes';
    term.write(data, () => {
      const buf = term.buffer.active;
      const lines = [];
      for (let i = 0; i < buf.length; i++) {
        lines.push(buf.getLine(i).translateToString(true).replace(/\s+$/, ''));
      }
      // A capture's output ends at the cursor, or at the last row holding
      // content when the cursor was left above it.
      let last = buf.baseY + buf.cursorY;
      for (let i = lines.length - 1; i > last; i--) {
        if (lines[i] !== '') {
          last = i;
          break;
        }
      }
      resolve(lines.slice(0, last + 1).join('\n'));
    });
  });
}

(async () => {
  const cols = Number(process.env.COLS || 200);
  const rows = Number(process.env.ROWS || 500);
  process.stdout.write(await settle(fs.readFileSync(process.argv[2]), cols, rows));
})();
