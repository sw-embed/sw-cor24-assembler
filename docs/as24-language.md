# as24 Assembly Language Specification

The source language accepted by sw-as24 and by all reference
assemblers in the COR24 ecosystem (makerlisp as24.c,
sw-cor24-x-assembler, cor24-rs cor24-run `--assemble`). This
spec is reverse-engineered from the makerlisp `as24.c` source;
it is normative for sw-as24.

## 1. Source Format

### 1.1 Lines

Source is a sequence of lines terminated by `\n`. Maximum line
length is **132 characters** (as24.c `LINSIZ`). Longer lines are
an error.

A line is, in order:

1. Optional leading whitespace (spaces or tabs).
2. Optional label, symbol definition, directive, or instruction.
3. Optional comment starting with `;`, running to end of line.
4. Trailing whitespace / newline.

Blank lines and comment-only lines are legal and have no effect
on emitted code.

### 1.2 Tokens

A line is split into at most **32 tokens** (`MAXTOKS`) of up to
**32 characters each** (`TOKLEN`). Token separators are:

- whitespace (space, tab)
- `,` (comma)
- `(` and `)`

The tokenizer has one quirk for indirect addressing: a bare `(`
introduces a synthetic `0` token *before* the opening paren.
That is, `jmp (r1)` tokenizes as `jmp 0 r1`, and
`lw r0, 3(fp)` tokenizes as `lw r0 3 fp`. The assembler uses
this shape to recognize `disp(rb)` forms.

### 1.3 Comments

Comments begin with `;` and extend to end of line. A comment
may appear alone on a line or after any other content. There is
no multi-line comment syntax. Hash (`#`) is *not* a comment in
as24, though x-assembler and some IDEs tolerate it informally —
sw-as24 must reject or ignore `#` consistently; pick one and
stick with it (current recommendation: treat `#` as part of a
token, matching as24.c).

### 1.4 Case

Case is **significant** for mnemonics, register names,
directives, and symbols. All reference mnemonics and register
names are lowercase. Symbols and labels are case-sensitive
identifiers.

## 2. Lexical Elements

### 2.1 Identifiers (symbols, labels)

An identifier is a token that is not a number and is not a
reserved mnemonic/register/directive. No explicit grammar is
defined in as24.c beyond "does not start with a digit". In
practice:

- Must start with a non-digit character.
- May contain letters, digits, `_`, and `.` (the period is used
  in some existing `.s` files for hierarchical labels).
- Implementation limit: 32 characters (`TOKLEN`).

### 2.2 Numbers

Two forms:

- **Decimal:** optional `-` or `+` followed by digits.
  Examples: `42`, `-7`, `+128`.
- **Hexadecimal:** digits with a trailing `h`. Example: `ffh`,
  `7bh`, `123456h`. Hex numbers **must begin with a digit** (use
  a leading `0` if the first hex digit is `a`..`f`): `0ffh`, not
  `ffh` — wait, let me re-verify. as24.c's `scani32` checks
  `isdigit(s[0])` before applying hex parsing, so the first
  character must be `0`..`9`. A token starting with `a`..`f` is
  not recognized as hex. Example: `0a5h` is hex 0xA5; `a5h`
  would be treated as an identifier.

Range constraints are enforced per operand type:

| Operand | Range |
|---------|-------|
| `i8` (signed 8-bit immediate) | −128 … 127 |
| `u8` (unsigned 8-bit immediate) | 0 … 255 |
| `d8` (signed PC-relative displacement) | −128 … 127 |
| `o8` (signed base+disp offset) | −128 … 127 |
| `i24` (signed 24-bit immediate) | −(2²⁴) … (2²⁴)−1 (inclusive of both endpoints) |
| `d24` / 24-bit address | 0 … (2²⁴)−1 |

Out-of-range literals are a compile-time error.

### 2.3 Register names

Recognized register tokens — these are the **only** valid
register names the assembler accepts:

`r0`, `r1`, `r2`, `fp`, `sp`, `z`, `iv`, `ir`, `c`

Only the three general-purpose registers carry an `r` prefix.
`r3`, `r4`, `r5`, `r6`, `r7` are **not** valid register names
and must not appear in source. The hardware decode ROM uses
3-bit selector values 0..7 internally; those values are
encoding details, never user-visible names. Treating a token
like `r3` as a register is a compatibility bug — reject it as an
unknown identifier.

`c` appears in `mov ra, c` (read the condition flag into a
register) and nowhere else. `iv` appears only in `mov iv, r0`.
`ir` appears only in `jmp (ir)` and in the `la ir, imm24`
encoding slot.

## 3. Labels and Symbols

### 3.1 Labels

A label is an identifier followed by `:`, standing alone on its
line:

```asm
loop:
        add     r0, r1
```

The label takes the value of the current location counter at
its point of definition. Labels must be unique within a
translation unit (`dupsym` check). **A label must be on its own
line** — `loop: add r0, r1` is *not* accepted by as24.c, and
sw-as24 follows the same rule. (sw-cor24-x-assembler enforces
this explicitly and emits "label must be on its own line
(as24 compatible)".)

### 3.2 Symbol definitions

A symbolic constant is declared as:

```asm
NAME = value
```

where `value` is a 24-bit signed literal. The name is
case-sensitive. Redefinition is an error.

```asm
UART_DATA = 0FF0100h
LED_MASK  = 1
```

### 3.3 Scope

as24.c treats all symbols as file-scope. Labels starting with
the letter `L` are considered *local* for unreferenced-symbol
pruning (the `-O` optimizer removes unreferenced symbols whose
names begin with `L`). sw-as24 is not required to replicate
optimizer behaviour but should preserve the naming convention
when generating labels.

## 4. Directives

All directives begin with a period. Recognized directives:

| Directive | Operands | Effect |
|-----------|----------|--------|
| `.text` | — | Switch to text section (code). Default on assembler start |
| `.data` | — | Switch to data section (initialized data) |
| `.bss` | — | Switch to BSS section (uninitialized data) |
| `.byte` | `u8, u8, …` | Emit N unsigned bytes |
| `.word` | `i24, i24, …` | Emit N 24-bit little-endian words |
| `.word` | `symbol` | Emit a 24-bit word holding the value of `symbol` |
| `.comm` | `name, size` | Declare a common block of `size` bytes |
| `.globl` | `name` | Mark `name` as externally visible |
| `. = . + N` | — | Advance the location counter by `N` bytes |

Notes:

- `.byte` values are unsigned 0..255. Character literals are
  **not** supported by as24.c — pass the numeric value.
- `.word` accepts either a list of 24-bit numeric constants or
  a single symbol name. Mixed lists (numeric + symbol) are not
  supported in one directive.
- Section order in output is always text → data → bss
  regardless of the order in source.
- Bare 24-bit numeric literals on their own line default to
  `.word` data emission (as24.c "default word data
  initialization"). sw-as24 may accept this but need not emit
  it — it is a rare idiom.
- A bare unresolved symbol on its own line (not a directive,
  not an instruction, not a label) is also treated as a
  `.word symbol` data reference.

## 5. Instructions

### 5.1 Syntax

```
mnemonic [operand1 [, operand2 [, operand3]]]
```

Operands are separated by commas (or by `(`, `)` for indirect
forms). Whitespace around separators is optional.

### 5.2 Operand kinds

| Kind | Syntax | Matches |
|------|--------|---------|
| Register | `r0`, `r1`, `r2`, `fp`, `sp`, `z`, `iv`, `ir`, `c` | Fixed set |
| Signed imm8 | `-128` … `127` or `ffh` (within range) | Used by `add ra, imm8`, `lc`, branch disp |
| Unsigned imm8 | `0` … `255` | Used by `lcu` |
| PC-relative | label name (for `bra`, `brt`, `brf`) | Assembled as 8-bit signed displacement to label |
| Base + disp | `disp(rb)` — `disp` in range −128..127, `rb` one of r0, r1, r2, fp | Used by `lb`, `lbu`, `lw`, `sb`, `sw` |
| Register indirect | `(ra)` — `ra` a register | Used by `jmp`, `jal` |
| 24-bit immediate | decimal or hex in range | Used by `la`, `sub sp, imm24` |
| 24-bit address | label name | Used by `la` when operand is a symbol; synthesized `jmp imm24` |

### 5.3 Forward references

Labels may be referenced before they are defined. as24.c does
this in two passes:

1. Scan source; build symbol table; assemble each form,
   leaving placeholders (`bytes[1..3] = 0`) for unresolved
   symbols.
2. Walk the form list; fill in each symbol's value. If a
   PC-relative branch's target is out of range, rewrite it (see
   §5.4). Loop until no rewrites happen.

sw-as24 must also accept forward references. The two-pass
structure is the natural implementation.

### 5.4 Branch-too-far rewriting

When a conditional branch cannot reach its target:

- `brf` → `brt` (or vice versa) to a synthetic label, plus a
  `jmp absolute` to the original target. The `bra` case is
  simpler: replace with `jmp absolute`.

This is performed transparently by as24.c's `fixbra()`. sw-as24
must implement equivalent behaviour if it claims byte-identical
output on nontrivial programs — `fib.s` and `sieve.s` exercise
the rewrite path.

### 5.5 Optimizer (optional)

as24.c with `-O` applies a series of peephole optimizations:

- `sub sp, imm24` → `add sp, imm8` when the value fits.
- Fold adjacent `add sp, ...` pairs.
- Delete `add sp, 0`.
- `add sp, ...` immediately before `mov sp, fp` → drop the add.
- `brf L; bra T; L:` → `brt T`.
- Redirect branches through unconditional branches.
- Drop code in the shadow of an unconditional branch.
- Prune unreferenced local labels (names beginning with `L`).
- Simplify `clu z, rN; mov rN, c` compare-then-complement
  patterns.
- After `mov rN, c` drop following `sxt`/`zxt` on the same reg.
- Fold `mov rN, c; mov rX, rN` → `mov rX, c`.

sw-as24 **is not required** to implement `-O`. byte-identity
tests are against non-`-O` output.

## 6. Errors

as24.c reports errors on stderr in the form:

```
? Line N: <message>
```

Examples:
- `? Line 3: duplicate symbol definition: foo`
- `? Line 7: unknown instruction/directive: 'wibble r0 r1'`
- `? Line 12: unresolved symbol: not_defined`
- `? Line 20: label too far for branch`
- `? Line 25: too many tokens`
- `? Line 28: token '....' too long`

The process exit code is 0 on success, non-zero if any error
was reported. (The cor24-run `--assemble` bootstrap tool
historically printed errors to stdout and exited 0 regardless —
see `scripts/build.sh` for the workaround. sw-as24 should
follow as24.c's convention: stderr for errors, nonzero exit on
failure.)

## 7. Canonical Examples

The cor24-rs tree ships two reference sources that exercise the
full grammar:

- `cor24-rs/docs/research/asld24/fib.s` — Fibonacci via
  recursion; exercises the full calling convention, forward
  references, branch targets.
- `cor24-rs/docs/research/asld24/sieve.s` — Sieve of
  Eratosthenes; exercises arrays, loops, memory-mapped I/O,
  branch-too-far.

sw-as24 should assemble both to bytes identical to the
reference oracle (see `docs/oracle-protocol.md`). These files
should be copied into `tests/corpus/` once the oracle is wired
up.

## 8. Provenance

Authoritative sources, in decreasing authority:

1. `cor24-rs/docs/research/asld24/as24.c` — makerlisp reference
   implementation; defines tokenizer, directive set, error
   messages, branch rewriting, optimizer semantics.
2. `sw-cor24-x-assembler/src/assembler.rs` — Rust reference
   parser; clarifies the "label on own line" rule and literal
   syntax.
3. Working `.s` sources across the sw-embed ecosystem
   (`fib.s`, `sieve.s`, `nop.s`, `uart_hello.s`, etc.) for
   idiomatic usage.

## 9. Open Questions

- **Hex literal rule:** as24.c requires hex to begin with a
  digit (`0ffh`) because `scani32` tests `isdigit(s[0])` first.
  Confirm: does any existing `.s` source rely on `ff h` or `$ff`
  or `0xff`? If so, sw-as24 needs to accept the superset.
  Current best guess: all existing `.s` use the `0...h` form.
- **Character literals:** none documented in as24.c, but
  `.byte 'A'` would be a natural extension. Neither required
  nor forbidden for sw-as24; pick once and document.
- **String literals:** same — no support in as24.c. `.ascii`
  and `.asciiz` are traditional directives and are worth adding
  in a later revision.
- **Expressions:** as24.c accepts only single literals or
  symbols, not arithmetic (e.g. `.word base + 4` is **not**
  supported). sw-as24 follows suit until a real need arises.
