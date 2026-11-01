# WSL2 调用 Windows PowerShell 构建 FlowLog

本项目的 0.2 原生版使用 Windows .NET Framework、WPF 和 AvalonEdit；WSL2 只负责启动 Windows 构建环境，不是在 Linux 中编译 WPF。

## 前提

- Windows 已安装 .NET Framework 4.8 或更高版本，且存在 `%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe`。
- WSL2 可调用 `cmd.exe` 和 `wslpath`。
- 首次构建需要下载 AvalonEdit；打包需要下载 NSIS。脚本会校验下载文件的 SHA-256。

## 两种 PowerShell 路径

### 推荐：PowerShell 7（pwsh）

PS7 原生支持 UTF-8，无 BOM 问题，子进程调用无需额外绕路：

```bash
cd C:\Users\marvin\llm-zone\logseq-lite\flowlog
"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\build-native.ps1 -Tests
"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\package-native.ps1 -SkipBuild
"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\smoke-native.ps1 -Installed
```

### 备选：PowerShell 5.1

PS5.1 有两个已知问题，需要通过 `cmd.exe` 桥接：

```bash
# 编译 + 测试
cmd.exe /c "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\build-native.ps1 -Tests"

# 打包
cmd.exe /c "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\package-native.ps1 -SkipBuild"

# 冒烟测试（需补 BOM）
printf '\xEF\xBB\xBF' > scripts/.smoke-native.bom.ps1
cat scripts/smoke-native.ps1 >> scripts/.smoke-native.bom.ps1
cmd.exe /c "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts\.smoke-native.bom.ps1 -Installed"
rm -f scripts/.smoke-native.bom.ps1
```

## 遇到的问题与规避

| 问题 | 现象 | 解决 |
|---|---|---|
| PS5.1 子进程静默失败 | 直接从 WSL 调用 `powershell.exe` 启动 csc.exe 无输出无 exit code | 通过 `cmd.exe` 作为父进程启动 PowerShell |
| PS5.1 中文解析错误 | smoke-native.ps1 含中文字符串无 BOM，PS5.1 按 ANSI 读取时报解析错误 | 临时补 UTF-8 BOM，执行后删除；PS7 无需此操作 |
| NSIS 下载被拒绝 | GitHub 直连下载 NSIS 被拒（网络受限） | 设置 `$PSDefaultParameterValues['Invoke-WebRequest:Proxy']='http://192.168.10.8:20171'` |

## 产物

- `native/out/` — 可执行文件（FlowLog.Native.exe, FlowLog.Tests.exe）和依赖
- `native/packages/` — 安装包（~288KB）和便携 ZIP（~267KB）
- `native/TestResults/native-smoke.json` — 冒烟测试报告
- `native/TestResults/native-tests.json` — 单元测试汇总

本机验证：113 项原生测试通过，安装/卸载冒烟测试通过，工作集约 67MB。

## 建议

- 优先使用 PowerShell 7（`pwsh`），避免 BOM 问题。
- 若使用 PS5.1，封装构建命令以避免手动补 BOM。
