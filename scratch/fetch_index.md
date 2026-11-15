# Index-fetch draft

Approved and incorporated: `fetchIndex` in `src/main.zig`, after the imports and before `main`.
The scratch test imports the incorporated function through the `zigup_main` module.
The user explicitly approved the function and placement before incorporation.

## Verification

- Compiler: `0.18.0-dev.1124+2ecf4b5e2`, Apple Silicon macOS.
- Original draft command: `zig test zigup/scratch/fetch_index.zig --cache-dir /tmp/zigup-local-cache --global-cache-dir /tmp/zigup-global-cache`
- Incorporated-function command (from workspace root): `zig test --cache-dir /tmp/zigup-local-cache --global-cache-dir /tmp/zigup-global-cache --dep zigup_main -Mroot=zigup/scratch/fetch_index.zig -Mzigup_main=zigup/src/main.zig --test-filter 'fetch official index'`
- Incorporated-function live test passed: 90,290 bytes; master `0.18.0-dev.1151+8dfb7a7cc`; no allocator leaks reported. Formatting check passed.
- Project build passed from `zigup/`: `ZIG_GLOBAL_CACHE_DIR=/tmp/zigup-global-cache zig build --cache-dir /tmp/zigup-local-cache --prefix /tmp/zigup-build-output`. Diff whitespace check passed.
- Initial restricted run failed with `UnknownHostName`; authorized network retry passed.
- Received 90,290 bytes, parsed valid JSON, and found nonempty `master.version` (`0.18.0-dev.1151+8dfb7a7cc`).
- Testing allocator reported no leaks.
- The successful connection was direct; proxy support is configured through the standard library but routing through a proxy is unverified.
- External state: DNS, network, system certificates, proxy environment, and the changing official index. This live test does not establish repeatability.

## Waiting work

- [x] Review function and placement; incorporate after explicit approval and verify there.
- [ ] Proxy routing: unchecked; a proxy-specific failure could block fetching. Deferred because the direct request succeeded. Revisit when using the personal network's proxy.
- [ ] HTTP error responses, interrupted transfers, TLS failures, and allocation failures: cleanup/error paths untested. Deferred to keep the first test focused on fetching; revisit when failure handling becomes the current feature.
- [ ] Response size bound and timeout policy: currently uses an allocating writer and standard client behavior; a large or stalled response can consume memory or delay completion. Revisit when deciding refresh resource limits.
- [ ] Malformed JSON/host metadata validation and snapshot preservation belong to roadmap steps 2–3. This function returns bytes without validating or saving them; revisit before implementing save-and-report.

Reuse note: this is the first buffered HTTP-response implementation. Reconsider shared logic if another function repeats it.
