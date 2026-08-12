# ANSI replay fixtures

Each pair is a real cli-ui capture (`.raw`) and the text xterm.js settles on
after processing it (`.expected`).

The point is the provenance of `.expected`: it is **not** produced by
`ANSI.replay`. It comes from [xterm.js][], the emulator behind VS Code, so the
fixtures assert agreement with an independent terminal emulator rather than
agreement with ourselves. They are xterm.js fixtures, not a claim that every
terminal emulator behaves identically. `replay_fixtures_test.rb` only reads the
committed files, so neither node nor xterm.js is needed to run the suite.

## Regenerating

```sh
bundle exec rake replay:capture   # re-render the .raw captures from cli-ui
bundle exec rake replay:bless     # re-derive the .expected files from xterm.js
```

`replay:bless` needs node and the locked dependencies installed in this
directory:

```sh
npm ci
```

Captures are timing-dependent: re-running `replay:capture` yields a different
number of spinner frames, which is fine — bless afterwards. Review a blessed
diff before committing it. If `.expected` changes without an intended behavior
change, xterm.js is telling you something.

## Scope

Only captures that fit the oracle's viewport can be blessed this way. `oracle.js`
uses a 200x500 screen with 100k lines of scrollback, so nothing in these fixtures
scrolls; a capture that scrolled would need screen coordinates that replay
deliberately does not model.

Four differences from xterm.js are known and expected, so don't add a fixture
that leans on them:

- **Viewport operations.** Absolute positioning (CUP, HVP), display erasure
  (ED), scroll margins (DECSLRM) and scroll-left/right are ignored by replay by
  design; xterm.js applies them. Callers can detect such streams through the
  optional `diagnostics[:viewport_operations_seen]` flag.
- **VT and FF.** The oracle's `convertEol` homes the column for `\n`, `\v` and
  `\f` alike. A tty's ONLCR translates only `\n`, which is what replay models.
- **Trailing blank rows.** A fixed-height buffer cannot say whether a blank row
  below the cursor is content, so a capture ending in an inserted blank line
  reads one line shorter in the oracle.
- **Graphemes split by an escape sequence.** Replay re-segments `e\e[31m\u0301`
  into one cell; xterm.js resets its cluster state at the sequence and gives the
  mark its own cell.

[xterm.js]: https://github.com/xtermjs/xterm.js
