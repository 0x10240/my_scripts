# Windows 安装说明

这份说明对应 [install.ps1](D:/Codes/my_scripts/claude-code-install-cn/install.ps1) 的实际行为。

## 会不会加入环境变量

会，但准确地说，脚本加入的是命令所在的目录，而不是单独把 `npm` 或 `claude` 这两个命令名写进环境变量。

脚本会修改当前用户的 `Path`，不是系统级 `Path`。

加入规则如下：

1. 一定会加入 Claude Code 的安装目录：

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global
```

这样新的终端里就可以直接运行：

```powershell
claude
```

2. 如果本机没有可用的 Node.js，或者版本低于 `18`，脚本会额外安装便携版 Node.js，并把这个目录加入用户 `Path`：

```text
%LOCALAPPDATA%\ClaudeCodeCN\node
```

这样新的终端里也可以直接运行：

```powershell
node
npm
```

3. 如果你机器上已经有可用的系统 Node.js / npm，脚本不会重复安装便携版 Node，也不会改动你现有 Node.js 的路径。

这时：

- `npm` 继续走你系统里原本的 Node.js / npm
- `claude` 走脚本安装出来的目录 `%LOCALAPPDATA%\ClaudeCodeCN\npm-global`

## 默认安装目录

PowerShell 脚本默认的安装根目录是：

```text
%LOCALAPPDATA%\ClaudeCodeCN
```

在默认情况下，各部分位置如下。

### 1. Claude Code 可执行入口

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global\claude.cmd
```

### 2. Claude Code 包本体

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global\node_modules\@anthropic-ai\claude-code
```

### 3. npm 全局前缀目录

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-global
```

这是脚本给 Claude Code 单独准备的 npm 全局安装目录。

### 4. npm 缓存目录

```text
%LOCALAPPDATA%\ClaudeCodeCN\npm-cache
```

### 5. 便携版 Node.js 目录

只有在本机 Node.js 不可用，或者版本低于 `18` 时才会安装：

```text
%LOCALAPPDATA%\ClaudeCodeCN\node
```

其中常用文件一般是：

```text
%LOCALAPPDATA%\ClaudeCodeCN\node\node.exe
%LOCALAPPDATA%\ClaudeCodeCN\node\npm.cmd
```

## 安装完成后什么时候生效

用户级 `Path` 已经被写入，但当前已经打开的旧终端不会自动刷新。

通常有两种方式：

1. 关闭当前 PowerShell / CMD，重新开一个新终端
2. 按脚本提示，在当前终端临时刷新 `Path`

如果脚本安装了便携 Node，当前会话可执行：

```powershell
$env:Path = "$env:LOCALAPPDATA\ClaudeCodeCN\npm-global;$env:LOCALAPPDATA\ClaudeCodeCN\node;$env:Path"
```

如果脚本复用了系统 Node.js，没有安装便携 Node，当前会话可执行：

```powershell
$env:Path = "$env:LOCALAPPDATA\ClaudeCodeCN\npm-global;$env:Path"
```

## 可自定义安装目录

可以在执行脚本时用 `-InstallRoot` 改掉默认目录，例如：

```powershell
.\install.ps1 -InstallRoot "D:\Apps\ClaudeCodeCN"
```

那对应目录就会变成：

```text
D:\Apps\ClaudeCodeCN
D:\Apps\ClaudeCodeCN\npm-global
D:\Apps\ClaudeCodeCN\node
D:\Apps\ClaudeCodeCN\npm-cache
```

## 额外会写入哪些环境变量

只有你在安装时主动传了这些参数，脚本才会写入对应用户环境变量：

- `-BaseUrl` -> `ANTHROPIC_BASE_URL`
- `-AuthToken` -> `ANTHROPIC_AUTH_TOKEN`
- `-ApiKey` -> `ANTHROPIC_API_KEY`
- `-CustomModel` -> `ANTHROPIC_CUSTOM_MODEL_OPTION`

如果你没有传这些参数，脚本不会平白多写它们。

## 一句话总结

- `claude` 会加入用户 `Path`
- `npm` 只有在脚本安装了便携版 Node.js 时，才会通过 `%LOCALAPPDATA%\ClaudeCodeCN\node` 一起加入用户 `Path`
- 默认安装根目录是 `%LOCALAPPDATA%\ClaudeCodeCN`
