# sw-cor24-assembler

Native COR24 assembler written in C — runs directly on COR24 FPGA hardware.

## Overview

A two-pass assembler that processes COR24 `.s` assembly source and
produces machine code. Written in C, compiled by the cross C compiler
(`sw-cor24-x-tinyc` / `tc24r`), and runs natively on COR24 hardware.

This is a key component of the self-hosted development environment:
with a native assembler on COR24, all assembly-based toolchains
(Forth, p-code VM, etc.) can be built on-device without a host PC.

## Naming Convention

| Repo | Role | Written in | Runs on |
|------|------|-----------|---------|
| `sw-cor24-x-assembler` | Cross-assembler | Rust | Host (x86/ARM) |
| `sw-cor24-assembler` | Native assembler | C | COR24 FPGA |

The `x-` prefix denotes cross-tools that run on a host machine.
The plain name is the native tool that runs on COR24 hardware.

## Bootstrapping

```
sw-cor24-x-tinyc (Rust)  compiles  cas24.c  →  cas24.s
sw-cor24-x-assembler (Rust)  assembles  cas24.s  →  cas24.bin
cas24.bin runs on COR24 FPGA  →  native assembler available on-device
```

## Status

In development. See `.agentrail/saga.toml` for implementation progress.

## Related Repos

- [sw-cor24-x-assembler](https://github.com/sw-embed/sw-cor24-x-assembler) — Rust cross-assembler (reference implementation)
- [sw-cor24-x-tinyc](https://github.com/sw-embed/sw-cor24-x-tinyc) — Rust cross C compiler (used to compile this)
- [sw-cor24-emulator](https://github.com/sw-embed/sw-cor24-emulator) — COR24 emulator + ISA definitions

## License

See [LICENSE](LICENSE).
