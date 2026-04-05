# Windows Environment Assets

这个目录用于缓存面向 Windows 小白包的可复用官方资产，避免每次发版都重新去官方下载。

## 目录结构

```text
tools/environment-assets/windows/
├─ downloads/
│  ├─ node-v<version>-win-x64.zip
│  └─ MinGit-<version>-64-bit.zip
├─ playwright-browsers/
├─ fetch-official-assets.ps1
├─ prefetch-playwright-browsers.ps1
└─ manifest.local.json
```

## 资产说明

- `downloads/node-v<version>-win-x64.zip`
  - 来源：Node.js 官方发布归档
  - 用途：便携包内置 Node 运行时
- `downloads/MinGit-<version>-64-bit.zip`
  - 来源：Git for Windows 官方 MinGit 发布
  - 用途：兼容更新脚本或后续 Git 嵌入需求
  - 结构备注：官方 MinGit 以 `cmd\git.exe` 为主，因此 Windows 启动器需要把 `git\cmd` 放进 `PATH`
- `playwright-browsers/`
  - 用途：缓存与 OpenClaw 实际 Playwright 版本匹配的浏览器内核
  - 注意：当前仓库未包含 `openclaw/` 源码，因此不能在这里盲目下载一个“可能不匹配”的浏览器版本；应在具备真实应用源码后再按项目锁定版本预取

## 使用方式

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\environment-assets\windows\fetch-official-assets.ps1
```

脚本默认会：

- 下载与当前 Windows 构建脚本一致版本的 Node.js zip
- 下载 Git for Windows 官方最新稳定 MinGit 64-bit zip
- 生成本地 `manifest.local.json`

当仓库内已经存在真实的 `openclaw/` 源码后，再执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\environment-assets\windows\prefetch-playwright-browsers.ps1
```

这个脚本会：

- 临时解压本地缓存的官方 Node.js
- 优先按真实应用 `package.json` 中锁定的 Playwright 版本临时安装一个匹配的 CLI，避免每次都为预取浏览器安装整套 OpenClaw 依赖
- 使用与项目版本匹配的 Playwright CLI 预取浏览器
- 先写入临时 staging 目录，成功后再替换目标浏览器缓存目录，避免把旧缓存和新子集混在一起

## 与构建脚本的关系

- `build/build-windows.ps1` 会优先复用这里缓存的 Node.js zip
- 若 `playwright-browsers/` 目录后续被填充，构建脚本也会优先复用这里的浏览器资产
- 若需要比较不同浏览器子集，可以先用 `-OutputDir` 生成独立缓存，再通过 `build/build-windows.ps1 -PlaywrightBrowsersPath ...` 指向对应目录

## 不提交的内容

以下内容默认只保留在本地，不提交到 Git：

- `downloads/*`
- `playwright-browsers/*`
- `manifest.local.json`

## Latest Usage Notes

- `prefetch-playwright-browsers.ps1` now auto-detects OpenClaw source from either `openclaw/` or `openclaw-portable/openclaw/`.
- Use the default command below to prefetch the full Playwright browser set:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\environment-assets\windows\prefetch-playwright-browsers.ps1
```

- Use the command below to point at a specific source checkout and prefetch only Chromium-related assets into a separate comparison cache without overwriting the default full set:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\environment-assets\windows\prefetch-playwright-browsers.ps1 -OpenClawPath .\openclaw-portable\openclaw -BrowserSet chromium -OutputDir playwright-browsers-chromium
```

- Use the command below to build a Windows fat package against that Chromium-only cache:

```powershell
powershell -ExecutionPolicy Bypass -File .\build\build-windows.ps1 -Mode fat -PlaywrightBrowsersPath .\tools\environment-assets\windows\playwright-browsers-chromium
```
