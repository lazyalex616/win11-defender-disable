# Win11 Defender Disable

A portable Microsoft Defender switch for Windows 10/11, using Windows PowerShell 5.1 and superUser 6.2.

[简体中文](README.zh-CN.md) · [Discussions](https://github.com/lazyalex616/win11-defender-disable/discussions)

## Usage

1. Extract the complete archive. Release archive password: `defender`.
2. Run `关闭Defender.CMD` to disable or `启用Defender.CMD` to enable.
3. Accept the administrator prompt and read the result.

Exit codes: `0` verified, `1` incomplete, `2` error. No automatic reboot.

## Scope and limits

- Changes Defender monitoring settings, existing scan tasks, security services and tray startup.
- Protected services and tamper protection can block changes. Full engine shutdown is not guaranteed.
- Does not remove Defender components, change firewall settings, or automatically disable tamper protection.
- **defendnot is not integrated or bundled.** This release is the standalone script, not a one-click defendnot installer. Do not run it over an existing defendnot setup: it disables `wscsvc`, which defendnot requires.
- Enable does not undo legacy-script changes or unregister third-party antivirus products. The tray returns at the next sign-in.

## Checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\StaticChecks.ps1
```

These are static and isolated checks, not a live antivirus-disable test.

## License

New code: [MIT](LICENSE). Unmodified [superUser 6.2](https://github.com/mspaintmsi/superUser/releases/tag/v6.2) binaries: [Apache-2.0](LICENSE-superUser.txt).
Legacy local XML files are not used or distributed.
