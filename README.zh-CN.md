# Win11 杀毒关闭工具

适用于 Windows 10/11 的便携 Defender 开关，使用 Windows PowerShell 5.1 和 superUser 6.2。

[English](README.md) · [讨论区](https://github.com/lazyalex616/win11-defender-disable/discussions)

> [!IMPORTANT]
> **7z 压缩包解压密码：`defender`**

## 使用

1. 完整解压发布包，密码：`defender`。
2. 运行 `关闭Defender.CMD` 关闭，或 `启用Defender.CMD` 开启。
3. 同意管理员权限请求，查看执行结果。

退出码：`0` 检查通过，`1` 部分未完成，`2` 执行错误。不自动重启。

## 范围与限制

- 处理 Defender 监控设置、现有扫描任务、安全服务和托盘启动项。
- 防篡改与受保护服务可能拒绝修改，不保证彻底停止引擎。
- 不移除系统组件、不修改防火墙，不自动关闭防篡改。
- **尚未整合或内置 defendnot。** 当前发布包是独立脚本，不是一键 defendnot 安装器。已有 defendnot 时不要运行此脚本，它会禁用 defendnot 依赖的 `wscsvc`。
- 开启不会撤销旧版脚本的额外修改，也不会注销第三方杀毒产品。托盘在下次登录时恢复。

## 检查

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\StaticChecks.ps1
```

只进行静态和隔离检查，不执行实际杀毒开关。

## 授权

新写代码采用 [MIT](LICENSE)。未经修改的 [superUser 6.2](https://github.com/mspaintmsi/superUser/releases/tag/v6.2) 二进制采用 [Apache-2.0](LICENSE-superUser.txt)。
原包历史 XML 不被使用，也不随发布包分发。
