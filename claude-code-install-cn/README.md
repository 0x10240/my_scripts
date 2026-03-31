# Claude Code 国内一键安装脚本

这个目录提供两套安装脚本，目标是让国内用户尽量绕开 `claude.ai/install.sh` / `claude.ai/install.ps1` 这条容易卡住的官方原生安装链路，改为通过官方 npm 包 `@anthropic-ai/claude-code` 来安装 Claude Code。

默认使用的国内镜像：

- npm 镜像：`https://registry.npmmirror.com`
- Node.js 镜像：`https://npmmirror.com/mirrors/node`

适用场景：

- 你在国内网络环境下安装 Claude Code
- 你不想依赖官方原生安装器
- 你希望脚本自动处理 Node.js 依赖
- 你希望安装在用户目录，不动系统目录，不要求管理员权限或 `sudo`

## 目录说明

本目录下有这些文件：

- `install.ps1`：Windows PowerShell 安装脚本
- `install.sh`：Linux / macOS 安装脚本
- `WINDOWS-说明.md`：Windows 安装后的 PATH、目录结构、环境变量说明

## 安装原理

脚本的工作流程是：

1. 检查本机是否已有可用的 `node` / `npm`
2. 如果 Node.js 不存在，或者版本低于 `18`，则自动下载便携版 Node.js 到用户目录
3. 使用 npm 全局安装官方包 `@anthropic-ai/claude-code`
4. 将 `claude` 命令所在目录加入用户环境
5. 如果你传入了代理网关参数，则顺手写入 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_API_KEY` 等环境变量

这意味着它解决的是“安装链路尽量免翻墙”，不是“Anthropic 官方服务一定免翻墙”。如果你后续直接登录 Anthropic 官方账号，运行阶段仍可能访问：

- `claude.ai`
- `console.anthropic.com`
- `api.anthropic.com`

如果你本身就是通过国内代理网关、中转平台、兼容 API 网关使用 Claude Code，这套脚本会更合适。

## 安装前准备

建议先确认以下几点。

### 1. Windows 用户

建议准备：

- PowerShell 5.1 或更新版本
- 可联网
- 如果你要完整使用 Git 工作流，建议先安装 Git for Windows

Git 不是脚本运行的硬性前置条件，但 Claude Code 的很多工作流都和 Git 强相关。

### 2. Linux / macOS 用户

建议准备：

- `bash`
- `curl`
- `tar`
- 可联网
- 如果要完整使用 Git 工作流，建议已安装 `git`

### 3. Claude Code 账号/接入方式

你至少需要下面其中一种方式：

- 直接登录 Anthropic / Claude 官方账号
- 使用 Anthropic API Key
- 使用兼容 Claude Code 的代理网关

## Windows 安装教程

### 方式一：最常用安装

进入本目录，在 PowerShell 里执行：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

执行完成后：

- 如果你电脑里已有可用的 Node.js 18+，脚本会直接复用
- 如果没有，脚本会自动下载便携版 Node.js 到用户目录
- Claude Code 会安装到独立目录，不污染系统 npm 全局目录

### 方式二：安装时顺手写入代理网关地址

如果你走的是中转网关、代理 API、兼容 Anthropic 接口的服务，可以在安装时直接写入环境变量：

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1 `
  -BaseUrl "https://your-gateway.example.com/v1" `
  -AuthToken "your-token"
```

适用场景：

- 你的网关要求用 Bearer Token
- 你的网关不是 Anthropic 官方域名

### 方式三：使用 API Key

```powershell
.\install.ps1 -ApiKey "sk-ant-..."
```

### 方式四：自定义安装目录

默认安装目录是：

```text
%LOCALAPPDATA%\ClaudeCodeCN
```

如果你想改到别的目录：

```powershell
.\install.ps1 -InstallRoot "D:\Apps\ClaudeCodeCN"
```

### Windows 安装完成后怎么验证

安装完成后，建议做这几步：

1. 关闭当前 PowerShell，重新打开一个新终端
2. 执行：

```powershell
claude --version
```

3. 如果能输出版本号，说明命令已经可用
4. 再执行：

```powershell
claude
```

如果你要看 Windows 下到底改了哪些路径、`npm` 和 `claude` 是否都加入了 `Path`，请看：

- `WINDOWS-说明.md`

## Linux / macOS 安装教程

### 第一步：给脚本执行权限

```bash
chmod +x install.sh
```

### 第二步：直接安装

```bash
./install.sh
```

脚本行为：

- 如果本机已有 Node.js 18+，直接复用
- 如果没有，则自动下载便携版 Node.js 到用户目录
- Claude Code 安装到用户目录自己的 npm 前缀目录
- 自动写入 shell 配置文件，让后续终端直接能用 `claude`

### 第三步：如果你走代理网关，带参数安装

```bash
./install.sh \
  --base-url "https://your-gateway.example.com/v1" \
  --auth-token "your-token"
```

如果你是 API Key：

```bash
./install.sh --api-key "sk-ant-..."
```

### 第四步：安装完成后验证

重新开一个终端，或者手动加载环境：

```bash
. "$HOME/.local/share/claude-code-cn/env.sh"
```

然后执行：

```bash
claude --version
claude
```

### Linux / macOS 默认安装目录

默认根目录：

```text
~/.local/share/claude-code-cn
```

其中常见位置：

- Claude Code 命令：`~/.local/share/claude-code-cn/npm-global/bin/claude`
- npm 缓存：`~/.local/share/claude-code-cn/npm-cache`
- 便携 Node.js：`~/.local/share/claude-code-cn/node`
- shell 环境文件：`~/.local/share/claude-code-cn/env.sh`

### Linux / macOS 修改安装目录

```bash
./install.sh --install-root "/opt/claude-code-cn-user"
```

## 常见安装参数说明

### Windows 脚本参数

```powershell
.\install.ps1 `
  [-InstallRoot "D:\Apps\ClaudeCodeCN"] `
  [-NodeMirrorBaseUrl "https://npmmirror.com/mirrors/node"] `
  [-NpmRegistry "https://registry.npmmirror.com"] `
  [-BaseUrl "https://your-gateway.example.com/v1"] `
  [-AuthToken "your-token"] `
  [-ApiKey "sk-ant-..."] `
  [-CustomModel "your-model-id"]
```

参数含义：

- `-InstallRoot`：安装根目录
- `-NodeMirrorBaseUrl`：Node.js 下载镜像地址
- `-NpmRegistry`：npm registry 地址
- `-BaseUrl`：写入 `ANTHROPIC_BASE_URL`
- `-AuthToken`：写入 `ANTHROPIC_AUTH_TOKEN`
- `-ApiKey`：写入 `ANTHROPIC_API_KEY`
- `-CustomModel`：写入 `ANTHROPIC_CUSTOM_MODEL_OPTION`

### Linux / macOS 脚本参数

```bash
./install.sh \
  --install-root "/custom/path" \
  --node-mirror "https://npmmirror.com/mirrors/node" \
  --registry "https://registry.npmmirror.com" \
  --base-url "https://your-gateway.example.com/v1" \
  --auth-token "your-token" \
  --api-key "sk-ant-..." \
  --custom-model "your-model-id"
```

## 脚本会改哪些环境变量

### Windows

Windows 脚本会修改当前用户的 `Path`。

默认一定会加：

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global
```

如果脚本安装了便携版 Node.js，还会加：

```text
%LOCALAPPDATA%\ClaudeCodeCN\node
```

如果你传了这些参数，脚本还会写入：

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_CUSTOM_MODEL_OPTION`

### Linux / macOS

Linux / macOS 脚本不会直接粗暴改系统级环境变量，而是：

1. 生成一个环境文件
2. 把这个环境文件挂到你的 shell 配置文件里

环境文件默认是：

```text
~/.local/share/claude-code-cn/env.sh
```

它会写入：

- `PATH`
- `ANTHROPIC_BASE_URL`（如果有）
- `ANTHROPIC_AUTH_TOKEN`（如果有）
- `ANTHROPIC_API_KEY`（如果有）
- `ANTHROPIC_CUSTOM_MODEL_OPTION`（如果有）

## 常见问题

### 1. 为什么不用官方原生安装器

因为官方 Quickstart 主推的是：

- macOS / Linux：`curl -fsSL https://claude.ai/install.sh | bash`
- Windows：`irm https://claude.ai/install.ps1 | iex`

这条链路依赖 `claude.ai` / `downloads.claude.ai`，对国内用户不稳定。

### 2. 为什么脚本装出来的版本可能不是最新

因为默认走的是 `npmmirror`，镜像同步会有延迟。

以 `2026-03-31` 为例：

- 官方 npm registry 返回的是 `2.1.88`
- `npmmirror` 当时返回的是 `2.1.87`

如果你必须装最新版本，而且你的网络允许访问官方 npm registry，可以改参数。

Windows：

```powershell
.\install.ps1 -NpmRegistry "https://registry.npmjs.org"
```

Linux / macOS：

```bash
./install.sh --registry "https://registry.npmjs.org"
```

### 3. 安装完成后 `claude` 还是找不到

先排查这几个点：

1. 你是不是还在旧终端里
2. 重新打开一个新终端再试
3. Windows 下执行 `claude --version`
4. Linux / macOS 下先执行 `. "$HOME/.local/share/claude-code-cn/env.sh"` 再试
5. 检查安装目录里是否存在命令文件

Windows 常见位置：

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global\claude.cmd
```

Linux / macOS 常见位置：

```text
~/.local/share/claude-code-cn/npm-global/bin/claude
```

### 4. 已经有系统 Node.js，会不会被覆盖

不会。

脚本只会在 Node.js 不存在，或者版本低于 `18` 时，才安装便携版 Node.js。

如果你机器上已经有可用的 Node.js 18+：

- 脚本直接复用它
- 不会卸载你原来的 Node.js
- 不会改你的系统 npm 全局目录

### 5. 能不能完全免翻墙使用 Claude Code

不能保证。

这套脚本主要解决的是“安装阶段”尽量走国内镜像。真正运行 Claude Code 时是否能顺畅，还取决于：

- 你是直连官方 Anthropic
- 还是走国内代理网关
- 你的网络环境是否允许访问对应 API

## 推荐使用流程

如果你是普通用户，建议这样走：

1. 先直接运行本目录脚本安装
2. 用 `claude --version` 确认安装完成
3. 如果你直连官方，就直接执行 `claude` 看能否登录
4. 如果你走代理网关，重新运行脚本，把 `BaseUrl` 和 `AuthToken` 或 `ApiKey` 一起写进去

## 参考信息

以下信息是本 README 编写时核对过的：

- Claude Code Quickstart：`https://code.claude.com/docs/en/quickstart`
- Claude Code 环境变量文档：`https://code.claude.com/docs/en/env-vars`
- 官方 npm 包：`https://www.npmjs.com/package/@anthropic-ai/claude-code`

对应确认点：

- 官方当前仍提供原生安装器
- 官方 npm 包名是 `@anthropic-ai/claude-code`
- 当前 Node.js 要求是 `>=18`
- Claude Code 支持 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_API_KEY`
