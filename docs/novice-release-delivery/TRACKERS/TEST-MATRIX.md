# Novice Release Delivery Test Matrix

## Latest Evidence

- 2026-04-05: `prefetch-playwright-browsers.ps1` now supports isolated output directories and temporary matching Playwright CLI installation, so Chromium-only smoke no longer depends on a full OpenClaw dependency install.
- 2026-04-05: Focused Chromium-only smoke reached the real browser download step, but Playwright CDN requests failed with repeated `ECONNRESET` / 30s timeout; no final `playwright-browsers-chromium/` directory was committed.
- 2026-03-28: `build/build-windows.ps1 -Mode fat` completed successfully using cached `Node.js`, cached `MinGit`, cached Playwright browser assets, and auto-detected source `openclaw-portable/openclaw`.
- 2026-03-28: Real fat-build output now exists at `dist/openclaw-win-x64-fat/`.
- 2026-03-28: Dist smoke confirmed presence of `browsers/`, `data/`, `git/`, `node/`, `openclaw/`, `scripts/`, `start.bat`, `update.bat`, and `0.配置AI密钥.bat`.
- 2026-03-28: Treat `TEST-004` as `done / passed`.
- 2026-03-28: `TEST-005` remains pending because no clean Windows first-run machine validation has been executed yet.

## 使用说明

- 一行一个验证单元
- 本表只表示验证推进，不表示实现推进；实现状态看 `OUTLINE.md`
- `待验证` 默认是验证债，不等于重大阻塞点

| ID | 领域 | 层级 | 目标 | 覆盖对象 | 关联实现 | 状态 | 结果 | 验证方式 | 证据 | 文件位置 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TEST-001 | governance | manual | 确认项目级目标、范围、阶段顺序与执行文档已经固化 | 规划与执行文档 | `1.1`, `1.2` | done | passed | 人工核对 `PLANNING.md`、`OUTLINE.md`、`STATE.md`、`docs/novice-release-checklist.md` | 文档已创建且主线一致 | `docs/novice-release-delivery/*` | |
| TEST-002 | windows-build | manual | 确认 Windows 构建脚本可被 PowerShell 正确解析，并具备关键 fail-fast 校验 | `build/build-windows.ps1` | `2.1` | done | passed | PowerShell 解析器检查 + 人工核对关键分支 | `ParamBlockPresent` / `NoParseErrors`；缺失源码与共享资产已改为显式错误；缺失浏览器资产会给出明确警告 | `build/build-windows.ps1` | 已完成静态验证 |
| TEST-003 | windows-entry | manual | 确认用户主入口已收敛为“先启动，后在页面里配置 API”，兼容脚本不再是推荐首步 | `README.md`, `start.bat`, `0.配置AI密钥.bat` | `2.2`, `3.1`, `3.2` | done | passed | 人工核对 README 与脚本文案 | README、Windows 启动器、兼容配置脚本与兼容更新脚本口径一致 | `README.md`, `launchers/windows/*`, `openclaw-portable/*`, `portable/README.md` | 已完成静态验证 |
| TEST-004 | windows-build | smoke | 确认 Windows fat 包在具备源码与浏览器资产时可完整构建 | fat 构建流程 | `2.2`, `5.1` | done | passed | 实际执行 `build/build-windows.ps1 -Mode fat` | 构建成功；`dist/openclaw-win-x64-fat/` 已生成并人工确认包含 `browsers/`、`data/`、`git/`、`node/`、`openclaw/`、`scripts/` 与启动器 | `build/build-windows.ps1`, `dist/openclaw-win-x64-fat/` | 已完成真实 smoke |
| TEST-005 | windows-runtime | manual | 确认纯净 Windows 机器可在无 API Key 预配置的情况下首启进入产品页 | 首次启动流程 | `3.1`, `5.2` | todo | not_run | 纯净机器手工 smoke | 待回填 | `launchers/windows/start.bat` | 当前回合不阻塞 |
| TEST-006 | macos-distribution | manual | 确认 macOS 小白正式包形态与迁移任务已定义 | macOS 分发路径 | `4.1`, `4.2` | done | passed | 人工核对规划与任务拆解 | `DOMAINS/macos-distribution.md` 已定义目标形态、过渡方案与迁移任务；Unix 文案已同步 | `README.md`, `docs/novice-release-delivery/*`, `launchers/unix/*` | 当前为文档与脚本文案级完成 |
| TEST-007 | windows-assets | manual | 确认可复用的官方环境资产缓存目录已建立，并下载到本地复用目录 | Node.js / MinGit 资产缓存 | `2.3` | done | passed | 人工核对目录与拉取脚本；检查本地下载结果 | 已下载 `node-v22.22.1-win-x64.zip` 与 `MinGit-2.53.0.2-64-bit.zip`；本地 `manifest.local.json` 已生成 | `tools/environment-assets/windows/*` | 已完成本地资产缓存 |
| TEST-008 | windows-build | manual | 确认 Windows 构建脚本会优先复用本地 MinGit 缓存 | MinGit 运行时嵌入 | `2.4` | done | passed | 人工核对 `build/build-windows.ps1` 的 MinGit 解压分支 | 构建脚本已优先查找 `tools/environment-assets/windows/downloads/MinGit-*-64-bit.zip` 并解压到发行物 `git/` 目录 | `build/build-windows.ps1` | 已完成静态验证 |
| TEST-009 | windows-launcher | manual | 确认 Windows 启动器能兼容官方 MinGit 的 `cmd\\git.exe` 目录结构 | 启动器 Git 路径 | `2.5` | done | passed | 人工核对 `start.bat` / `update.bat` PATH 组装逻辑 | 已确认官方 MinGit 解压后存在 `cmd\\git.exe`；Windows 启动器现同时注入 `git\\cmd` 与 `git\\bin` | `launchers/windows/*`, `openclaw-portable/*` | 已完成静态验证 |
| TEST-010 | windows-assets | smoke | 确认 Chromium-only 浏览器缓存可独立预取，并可被 Windows builder 指向而不覆盖默认全量缓存 | Chromium-only browser cache flow | `5.2` | done | failed | PowerShell parser check + 实际执行 `prefetch-playwright-browsers.ps1 -BrowserSet chromium -OutputDir playwright-browsers-chromium` | 临时 Playwright CLI `1.58.2` 安装完成后进入真实浏览器下载；Playwright CDN 下载多次 `ECONNRESET` / 30s timeout，最终未写入输出目录 | `tools/environment-assets/windows/prefetch-playwright-browsers.ps1`, `build/build-windows.ps1`, `tools/environment-assets/windows/README.md` | 当前回合不阻塞默认 full-set 构建，但阻塞 Chromium-only 对比包验证 |
