# Memcached for Windows — ServBay Portable Build

[memcached](https://memcached.org/) is a high-performance, multithreaded,
event-based key/value cache store intended to be used in a distributed system.

This repository produces a **native Windows** build of memcached — no Cygwin, no
WSL, no compatibility layer. It is cross-compiled with
[MinGW-w64](https://www.mingw-w64.org/) into a native Windows `memcached.exe`,
based on the MinGW port from
[jefyt/memcached-windows](https://github.com/jefyt/memcached-windows) merged on
top of upstream [memcached](https://github.com/memcached/memcached).

It is maintained by [ServBay](https://www.servbay.com/) and packaged for
consumption by `ServBay-PKG-Builder-v1`.

## Downloads

Grab the latest archive from this repository's
[**Releases**](../../releases/latest).

Each release publishes:

| File | Description |
| --- | --- |
| `memcached-<version>-win64-mingw.zip` (or `win32`) | The portable build |
| `memcached-<version>-win64-mingw.zip.sha256` | SHA-256 checksum |

* Release tag: `memcached-<version>-win-<arch>` (e.g. `memcached-1.6.44-win-x64`).
* Verify the download against its `.sha256` file before use.

## How it's built

Releases are produced by the
[`Build Memcached for Windows`](.github/workflows/build-memcached-windows.yml)
workflow (`workflow_dispatch`, run manually):

* **Inputs:** `memcached_version` (e.g. `1.6.44`), `arch` (`x64` / `x86`),
  `skip_tests`.
* **Toolchain:** runs on `ubuntu-latest` (24.04) — *not* in Docker — using
  ubuntu's `gcc-mingw-w64`, so the toolchain is pinned and reproducible.
* **Self-test:** the cross-compiled `memcached.exe` is launched under
  [wine](https://www.winehq.org/) and load-tested with
  [mc-crusher](https://github.com/memcached/mc-crusher) (memcached's own
  `make test` cannot run a cross-compiled `.exe` natively).
* **Publish:** the archive plus its SHA-256 are attached to a GitHub Release.

## Environment

Minimum requirement: **Windows Vista / Windows Server 2008**.

* **NOTE:** `-s`/`--unix-socket` requires at least
  [Windows 10 version 1803](https://en.wikipedia.org/wiki/Windows_10_version_history#Version_1803_(April_2018_Update))
  / [Windows Server 2016 version 1803](https://en.wikipedia.org/wiki/Windows_Server_2016#Version_1803).
  Run `sc query afunix` to check whether the OS supports it; a socket-creation
  error will occur on unsupported systems.

## Running

* Just execute **`memcached.exe`** (options are the same except the unsupported
  ones below).
* Run **`memcached.exe --help`** for more info.

## Unsupported

These upstream options do not apply on Windows:

* **sasl** — use `-Y`/`--auth-file` with TLS/SSL enabled as an alternative.
* **`-u`/`--user`** — use Windows `runas`, Explorer's *Run as different user*,
  or other built-in Windows tools instead.
* **`-r`/`--coredumps`** — MinGW-w64 does not support coredumps; use native
  Windows crash dumps instead.
* **`-k`/`--lock-memory`** — Windows does not support locking all paged memory.
* **seccomp** — Linux-only.

## Bug reports

Use the issue tracker on GitHub.

**If you are reporting a security bug**, please contact a maintainer privately.
We follow responsible disclosure: reports are handled privately, a patch is
prepared, then a fix release is pushed and the bug can be posted publicly with
credit in the release notes.

## Credits

* [memcached](https://github.com/memcached/memcached) — upstream project.
* [jefyt/memcached-windows](https://github.com/jefyt/memcached-windows) — the
  original MinGW-w64 native Windows port.
