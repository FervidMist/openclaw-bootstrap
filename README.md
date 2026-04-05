# OpenClaw 部署工具箱

## 当前状态

- Windows `fat` 构建链路已通过实际 smoke，当前可产出 `dist/openclaw-win-x64-fat/`
- 当前阶段更准确地说是“Windows 小白包内部验收中”，还不能算“正式对外已验收”
- `TEST-005` 尚未完成：还没有在纯净 Windows 机器上做最终首启验证，因此暂不建议对外宣称“完全开箱即用”
- macOS / Linux 当前仍偏技术向，不属于已完成的小白正式发行包

本仓库用于打包和分发 OpenClaw 的跨平台部署工具。当前优先推进 **Windows 小白包**，macOS / Linux 仍以技术向启动链路为主；同时支持 **预装版（fat）** 和 **联网版（slim）** 两种分发模式。

---

## 项目结构

```text
openclaw-bootstrap/
│
├── build/                           # 构建脚本（开发者/打包者使用）
│   ├── build-windows.ps1            #   Windows 构建（PowerShell）
│   ├── build-unix.sh                #   macOS / Linux 构建（Bash）
│   └── prune-platform.js            #   核心：跨平台 node_modules 瘦身工具
│
├── launchers/                       # 各平台启动器模板
│   ├── windows/                     #   Windows 启动器（.bat 批处理）
│   │   ├── start.bat                #     一键启动
│   │   ├── update.bat               #     一键更新
│   │   └── 0.配置AI密钥.bat          #     可选：兼容模式 API 配置工具
│   └── unix/                        #   macOS / Linux 启动器（.sh 脚本）
│       ├── start.sh                 #     一键启动
│       ├── update.sh                #     一键更新
│       └── setup-key.sh             #     可选：兼容模式 API 配置工具
│
├── portable/                        # 跨平台共享文件
│   ├── scripts/set-key.js           #   API 密钥注入脚本
│   ├── data/openclaw.json           #   预置默认配置
│   └── README.md                    #   用户使用说明
│
├── openclaw/                        # OpenClaw 官方源码（可直接放在仓库根）
├── openclaw-portable/               # 便携包样例与兼容的嵌套源码布局
│   ├── openclaw/                    #   Windows builder 也可自动识别这里的源码
│   ├── start.bat                    #   样例启动器
│   └── README.md                    #   样例分发说明
│
├── dist/                            # 构建产物输出目录（已 .gitignore）
│
├── install_openclaw.sh              # Linux 服务器版：Docker 模式安装脚本
├── upgrade_openclaw.sh              # Linux 服务器版：热更新脚本
├── uninstall_openclaw.sh            # Linux 服务器版：卸载脚本
├── compose.yaml                     # Docker Compose 编排模板
└── Dockerfile                       # Docker 构建镜像
```

> 当前 Windows 构建脚本会自动识别 `openclaw/` 或 `openclaw-portable/openclaw/` 作为源码目录，因此 README 里的两种布局都属于受支持路径。

---

## 两种分发模式

| 模式 | 含义 | 包含 node_modules | 首次启动需联网 | 当前参考体积 | 适用场景 |
|:----:|------|:--:|:--:|-----------|---------|
| **fat** | 预装版 | ✅ 是（已平台瘦身） | ❌ 不需要 | Windows x64 当前构建约 `3.32GB`（未压缩，含 Playwright 浏览器） | 小白用户、离线环境 |
| **slim** | 联网版 | ❌ 否 | ✅ 需要 | 几十 MB 级 | 技术用户、网速好的场景 |

**fat 模式**会在构建时自动运行 `prune-platform.js`，删除所有非目标平台的原生二进制包（如 Windows 构建会删除全部 `linux-*`、`darwin-*` 的包），大幅压缩体积。

面向小白用户的正式发行，默认应优先选择 `fat` 包；`slim` 更适合技术用户或开发调试。
当前 `fat` 包已经能真实构建通过，但包体仍然偏大，后续还需要继续评估“全量浏览器”与“Chromium-only”之间的取舍。

---

## 快速构建

### Windows 版

```powershell
# 预装版（解压即用，推荐）
powershell -ExecutionPolicy Bypass -File .\build\build-windows.ps1 -Mode fat

# 联网版（包体小，首次启动需联网安装依赖）
powershell -ExecutionPolicy Bypass -File .\build\build-windows.ps1 -Mode slim
```

> 当前 Windows 构建脚本会自动识别 `openclaw/` 或 `openclaw-portable/openclaw/` 作为源码目录；若已预取 `tools/environment-assets/windows/playwright-browsers/`，`fat` 包会直接复用本地浏览器缓存。
>
> 若要评估 Chromium-only 发行物，可先执行 `tools/environment-assets/windows/prefetch-playwright-browsers.ps1 -BrowserSet chromium -OutputDir playwright-browsers-chromium`，再用 `build/build-windows.ps1 -PlaywrightBrowsersPath .\tools\environment-assets\windows\playwright-browsers-chromium` 构建对比包，而不覆盖默认全量缓存。

### macOS 版

```bash
# Apple Silicon (M1/M2/M3) 预装版
bash build/build-unix.sh darwin arm64 fat

# Intel Mac 联网版
bash build/build-unix.sh darwin x64 slim
```

### Linux 版

```bash
# x64 预装版
bash build/build-unix.sh linux x64 fat

# ARM64 联网版（树莓派等）
bash build/build-unix.sh linux arm64 slim
```

### 构建产物

所有产物输出到 `dist/` 目录，命名规则为 `openclaw-{平台}-{架构}-{模式}`：

```text
dist/
├── openclaw-win-x64-fat/
├── openclaw-win-x64-slim/
├── openclaw-darwin-arm64-fat/
├── openclaw-linux-x64-fat/
└── ...
```

将对应目录压缩为 `.zip`（Windows）或 `.tar.gz`（macOS/Linux）即可分发。当前已经过实际构建验证的是 `openclaw-win-x64-fat/`。

---

## 用户使用流程

### Windows 用户

1. 解压收到的压缩包到**纯英文路径**（如 `D:\openclaw-portable`）
2. 双击 `start.bat`，等待浏览器自动打开
3. 首次进入后，优先在 OpenClaw 页面内完成模型 / API 配置，并查看购买入口与说明
4. 仅当当前页面暂未提供配置入口时，再使用 `0.配置AI密钥.bat` 作为兼容兜底工具

> 更新建议：面向小白的正式发行包，优先通过重新下载新版压缩包来更新；`update.bat` 更适合仍保留 Git 仓库结构的兼容场景。
>
> 当前状态：Windows `fat` 包已实测构建通过，但尚未完成纯净 Windows 真机首启验证；对外发版前，建议至少补一次“无开发环境 / 普通用户权限 / 新机器”的 smoke。

### macOS / Linux 用户

```bash
# 赋予执行权限
chmod +x *.sh

# 启动
./start.sh

# 若当前页面暂未提供模型/API配置入口，再使用兼容脚本
./setup-key.sh
```

> 当前仓库中的 macOS / Linux 启动链路仍偏技术向，尚未达到与 Windows 小白正式包等价的双击体验。

---

## Linux 服务器版（Docker 部署）

适用于有 Linux 运维经验的用户或硬件盒子场景：

```bash
# 镜像模式安装
./install_openclaw.sh \
  --mode image \
  --image registry.example.com/openclaw:latest \
  --port 8080

# 源码构建模式
./install_openclaw.sh \
  --mode build \
  --git-repo https://github.com/openclaw/openclaw.git \
  --git-ref main \
  --port 8080

# 热更新
./upgrade_openclaw.sh --dir /opt/openclaw --git-ref main

# 卸载（仅停容器）
./uninstall_openclaw.sh --dir /opt/openclaw --mode containers
```

---

## 防坑指南

> [!CAUTION]
> **杀毒软件误报**：由于脚本调用了便携版 Node.js 并自动运行 npm 安装，极易被安全软件拦截。请在使用前暂时关闭杀毒软件或将整个目录加入白名单。

> [!WARNING]
> **路径限制（Windows）**：当前 `start.bat` 仍会拦截中文、空格或特殊字符路径。推荐解压到 `D:\openclaw-portable` 这类纯英文根目录；如果后续修掉这条限制，再同步修改本说明。

> [!TIP]
> **VC++ 运行库**：部分 Windows 电脑可能缺少 C++ 运行库导致闪退，请安装微软常用运行库合集后重试。

---

## 技术细节

- **Node.js 版本**：v22.22.1 LTS（OpenClaw 要求 ≥22.16.0）
- **包管理器**：pnpm v10+
- **环境隔离**：所有环境变量（`PATH`、`npm_config_prefix`、`PNPM_HOME`、`PNPM_STORE_DIR`、`PLAYWRIGHT_BROWSERS_PATH`、`OPENCLAW_STATE_DIR`）均劫持到便携包内部，绝不污染宿主系统
- **安全沙盒**：默认配置为 `workspace` 受限模式，AI 仅可访问 `data/workspace/` 目录
