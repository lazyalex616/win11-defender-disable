# Win11 杀毒关闭工具

适用于 x64 Windows 10/11 的便携 Defender 开关，内置 defendnot 1.6.0 和 superUser 6.2。

[English](README.md)

> [!IMPORTANT]
> **7z 压缩包解压密码：`defender`**

## 使用

1. 完整解压发布包，密码：`defender`。
2. 关闭前，先在 Windows 安全中心关闭“篡改防护”。
3. 运行 `Disable-Defender.cmd` 关闭，或 `Enable-Defender.cmd` 开启。
4. 同意管理员权限请求，查看执行结果。

退出码：`0` 检查通过，`1` 部分未完成，`2` 执行错误。不自动重启。

## 范围与限制

- 关闭时自动将内置 defendnot 部署到 `%ProgramFiles%\defendnot`，注册虚拟杀毒产品并创建 SYSTEM 开机任务，同时禁用现有扫描任务和隐藏托盘。
- 保留 `wscsvc` 运行：它负责安全中心的杀毒产品登记，不是扫描引擎。
- 开启时撤销 defendnot 注册、移除其开机任务，恢复 Defender 设置与托盘启动项。托盘在下次登录时恢复。
- 不移除系统组件、不修改防火墙，不自动关闭防篡改。
- 关闭期间保留 `%ProgramFiles%\defendnot`。Windows 更新可能恢复 Defender，不承诺重启后永久有效。
- 不撤回无关的旧版脚本修改，不移除其他杀毒软件。安全健康服务可能继续运行，成功表示 Defender 扫描引擎已停止，不表示移除了全部安全组件。

## 检查

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\StaticChecks.ps1
```

只进行静态和隔离检查，不执行实际杀毒开关。

## 授权

新写代码采用 [MIT](LICENSE)。未经修改的 [superUser 6.2](https://github.com/mspaintmsi/superUser/releases/tag/v6.2) 和 [defendnot 1.6.0](https://github.com/es3n1n/defendnot/releases/tag/v1.6.0) 二进制采用 Apache-2.0（[superUser 许可](LICENSE-superUser.txt)、[defendnot 许可](LICENSE-defendnot.txt)）。
原包历史 XML 不被使用，也不随发布包分发。
