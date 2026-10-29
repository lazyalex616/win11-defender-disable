# Win11 Defender Disable

A portable Microsoft Defender switch for x64 Windows 10/11, with defendnot 1.6.0 and superUser 6.2.

[简体中文](README.zh-CN.md)

> [!IMPORTANT]
> **7z archive password: `defender`**

## Usage

1. Extract the complete archive. Release archive password: `defender`.
2. Turn off Tamper Protection in Windows Security before disabling Defender.
3. Run `Disable-Defender.cmd` to disable or `Enable-Defender.cmd` to enable.
4. Accept the administrator prompt and read the result.

Exit codes: `0` verified, `1` incomplete, `2` error. No automatic reboot.

## Scope and limits

- Disable installs the bundled defendnot in `%ProgramFiles%\defendnot`, registers a virtual antivirus and adds its SYSTEM boot task. It also disables existing Defender scan tasks and hides the security tray.
- `wscsvc` stays running: Windows Security Center is required for the antivirus registration; it is not the scanning engine.
- Enable unregisters defendnot, removes its boot task and restores Defender settings and tray startup. The tray returns at the next sign-in.
- Does not remove Defender components, change firewall settings, or automatically disable tamper protection.
- Keep `%ProgramFiles%\defendnot` while disabled. Windows updates may restore Defender. No reboot-persistence guarantee is claimed.
- Does not undo unrelated legacy-script changes or remove other antivirus products. Security health services can remain running; success means the Defender scanning engine is inactive, not every security component has been removed.

## Checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\StaticChecks.ps1
```

These are static and isolated checks, not a live antivirus-disable test.

## License

New code: [MIT](LICENSE). Unmodified [superUser 6.2](https://github.com/mspaintmsi/superUser/releases/tag/v6.2) and [defendnot 1.6.0](https://github.com/es3n1n/defendnot/releases/tag/v1.6.0) binaries: Apache-2.0 ([superUser license](LICENSE-superUser.txt), [defendnot license](LICENSE-defendnot.txt)).
Legacy local XML files are not used or distributed.
