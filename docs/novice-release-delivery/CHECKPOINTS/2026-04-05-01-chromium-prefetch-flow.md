# Checkpoint 2026-04-05 01

## Summary

- Added isolated Chromium-only browser cache support to `tools/environment-assets/windows/prefetch-playwright-browsers.ps1` via `-OutputDir` plus staging-before-replace behavior.
- Changed the prefetch flow to install a temporary matching Playwright CLI from the real OpenClaw `package.json`, which avoids a full OpenClaw dependency install when the source tree is clean.
- Added `-PlaywrightBrowsersPath` to `build/build-windows.ps1` so Windows fat builds can target a comparison cache such as `playwright-browsers-chromium` without overwriting the default full browser cache.
- Updated `README.md` and `tools/environment-assets/windows/README.md` with side-by-side full-set vs Chromium-only commands.
- Recorded the new Chromium-only smoke result: the flow now reaches actual browser download, but Playwright CDN access failed with repeated `ECONNRESET` / timeout errors before any final cache directory was emitted.

## Validation

- Passed: PowerShell parser check for `tools/environment-assets/windows/prefetch-playwright-browsers.ps1`
- Passed: PowerShell parser check for `build/build-windows.ps1`
- Passed: documentation review for `README.md` and `tools/environment-assets/windows/README.md`
- Failed: `powershell -ExecutionPolicy Bypass -File .\tools\environment-assets\windows\prefetch-playwright-browsers.ps1 -OpenClawPath .\openclaw-portable\openclaw -BrowserSet chromium -OutputDir playwright-browsers-chromium`
  - Evidence: temporary Playwright CLI `1.58.2` installed in seconds, then Playwright browser CDN downloads failed with `ECONNRESET` and 30s timeout
  - Result: no final `tools/environment-assets/windows/playwright-browsers-chromium/` directory was written

## Validation Debt

- `TEST-005`: still pending a clean Windows first-run validation machine
- `TEST-010`: Chromium-only cache smoke is now script-valid but blocked on external Playwright CDN/network availability

## Risks

- The repo still cannot claim a clean-machine novice-ready Windows release until `TEST-005` completes.
- Chromium-only comparison builds now have a deterministic tool path, but the actual asset download is currently blocked by unstable Playwright CDN connectivity in this environment.

## Next

- Rerun the Chromium-only prefetch command when Playwright CDN/network access is available, then build a Windows fat comparison package with `-PlaywrightBrowsersPath`.
- Run `TEST-005` on a clean Windows machine and capture first-run evidence.

## Git

- Commit: `PENDING_COMMIT`
- Notes: Stable-node commit will be attempted after checkpoint creation.
