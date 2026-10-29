# Win11 Defender Disable · Win11 杀毒关闭工具

Windows 10/11 上用于尝试关闭、重新开启 Microsoft Defender 的便携工具。
保留两个中文 CMD 入口，使用 PowerShell 5.1 和 superUser 6.2 执行操作并检查最终状态。

## 使用

1. 下载完整项目，保留目录结构。
2. 双击 `关闭Defender.CMD` 或 `启用Defender.CMD`，同意管理员权限请求。
3. 查看结束结果。绿色表示本工具检查通过，黄色表示尚有未完成项目，红色表示执行错误。

退出码：`0` 检查通过，`1` 部分未完成，`2` 执行错误或取消提权。
不自动重启，不自动关闭防篡改保护，不自动添加杀毒排除项。

## 作用范围

- Defender 实时、行为、下载文件及脚本扫描相关设置。
- 已存在的四个 Defender 计划任务。
- `WinDefend`、`MDCoreSvc`、`WdNisSvc` 服务（存在时）。
- Windows 安全中心托盘策略和启动项，以及 `SecurityHealthService`、`wscsvc` 服务。

Windows 的防篡改和受保护服务机制可能拒绝修改，即使取得 SYSTEM 与 TrustedInstaller 权限也不例外。
因此本工具不承诺在所有 Windows 版本彻底关闭引擎，普通重启也不能保证补完失败操作。
开启检查针对上述项目，不代表恢复机器之前所有自定义设置或证明整机安全。

本版本不再删除 AMSI（供程序调用杀毒扫描的接口）注册项，不修改启动驱动、防火墙或 SmartScreen。
如果运行过旧版本，“开启”不会自动撤回旧版本对这些额外组件的修改。
检测到 Defender AMSI 注册项缺失时，会报告需要修复 Windows 组件，不填入猜测的注册表内容。
现有排除项保持不变，因此被排除的文件仍然不会扫描。

## 杀毒检测

旧版核心曾被识别为 `HackTool:Win32/DefenderControl!MTB`。
能够修改防护配置的工具可能触发安全软件检测，不能只凭工具名称判断是否误报。
请先核对来源与代码。工具不会自动恢复隔离文件或修改检测处置规则。

## 本次修复

- 用系统身份检查替代依赖英文输出的管理员检测，取消提权时停止。
- 统一开关逻辑，校验 superUser 官方 SHA-256，保留子进程退出码。
- 以最终状态判断结果，不再无条件显示成功。
- 不再以“手动启动”冒充禁用，不直接修改驱动和扫描组件注册信息。
- 通过服务管理接口启动服务，不直接等待服务 EXE 退出，不依赖托盘进行重复恢复。
- 缺失计划任务不使用陈旧模板自动重建，开启时报告缺失。

## 验证

在 Windows PowerShell 5.1 中执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\StaticChecks.ps1
```

该检查只解析源码、校验文件和危险操作约束，不执行开关，不代表系统上的开关功能已通过运行测试。

### 本机运行验证（2026-10-29）

- 已实际执行关闭、开启两条路径，SYSTEM 与 TrustedInstaller 身份检查通过。
- 防篡改开启时，关闭操作受到系统拒绝，实时防护和引擎仍开启，正确返回 `1`。
- 随后执行开启，防护设置、服务及四个计划任务恢复为开启。修正检查兼容性后重跑开启，返回 `0`。
- 本轮不能证明能在防篡改关闭的系统上彻底停止引擎，没有修改防篡改设置或重启系统。

后续按明确授权继续关闭：通过 Windows 安全中心关闭本机防篡改，实时、行为、下载和脚本扫描均已关闭。
四个计划任务、托盘启动项已禁用，托盘进程已退出，`wscsvc` 已停止并禁用。
`SecurityHealthService` 已禁用启动但仍运行，`WdNisSvc` 已停止但仍为手动启动。
`WinDefend`、`MDCoreSvc` 仍为运行和自动启动，受保护服务拒绝在线修改，**尚未彻底关闭引擎**。
托盘 Shell 删除请求未得到确认，不能把进程消失等同于屏幕残影已经清除。
未重启、未进入安全模式、未修改离线系统，未再次执行开启。

## 问题根因与处理

### 关闭后托盘图标残留

旧脚本直接结束 `SecurityHealthSystray.exe`，没有先删除右下角的通知图标。
图标由资源管理器显示，进程退出后可能仍然留在屏幕上，直到鼠标划过才刷新。
结束杀毒引擎并不等于删除托盘图标。

当前脚本设置 `HideSystray` 隐藏策略、删除 `SecurityHealth` 开机启动项，
请求系统删除托盘图标，再结束托盘进程，不重启资源管理器，也不清空其他程序的托盘缓存。
本机托盘进程和启动项已移除，但系统未确认图标删除请求，尚不能保证当前屏幕残影已清除。

### 开启时窗口一直等待

旧脚本直接运行 `MsMpEng.exe` 和 `SecurityHealthService.exe`，等待它们退出后才继续。
这些是长期运行的服务程序，并不保证立即退出。旧脚本还根据托盘是否出现，
最多重复整套开启操作 30 次，但托盘是否出现不能作为杀毒是否正常的判断依据。

当前通过系统服务管理接口启动服务，再检查实际服务和防护状态，
不再等待托盘程序退出，也不再根据图标反复执行开启操作。
开启时恢复托盘启动项，下次用户登录时在正确的桌面启动托盘。
停止服务改用 `sc.exe` 发出请求，避免一直等待服务退出。
受保护服务拒绝操作时，仍如实报告未完成。

上面的本机状态记录截至 2026-10-29，电脑为 `NON-GM-DESKTOP`，Windows 内部版本为 `26300`。
它不代表以后一直保持不变，也不把部分关闭当作全部关闭成功。

## 来源与授权

- superUser：https://github.com/mspaintmsi/superUser ，使用官方 6.2 Intel 二进制，遵循 Apache-2.0。
- 原始中文批处理包日期为 2021-09-05，未附明确作者和授权。当前核心及入口已重写。
- 本地保留的四个 `Bin/Windows Defender *.xml` 是原包历史资料，作者和授权未能确认。当前代码不调用，也不上传到公开仓库。
- 新写代码采用 MIT，见 `LICENSE`；第三方组件与历史资料不包含在该授权内。

### superUser 6.2

- 作者：mspaintmsi。
- 源码：https://github.com/mspaintmsi/superUser
- 发布页：https://github.com/mspaintmsi/superUser/releases/tag/v6.2
- 内置 Intel 二进制为未经修改的官方发布文件，采用 Apache License 2.0，许可证全文附在下方。
- `superUser32.exe` SHA-256：`cdaad2ba1c179c43a079d7f82c11b44ff6bd476cc209c8d20f3035134f6a2a8a`
- `superUser64.exe` SHA-256：`d077f8b5448ef64cb1de5777b38996b09b99a4f0fde002503e8839b72bdc394f`

### Apache 许可证 2.0 中文译文

以下为便于阅读的非官方中文译文。如与英文原文有出入，以原文为准。

**Apache 许可证，2.0 版，2004 年 1 月**

许可地址：http://www.apache.org/licenses/

#### 1. 定义

“许可证”指本文第 1 至第 9 条规定的使用、复制和分发条件。

“许可方”指授予本许可证的版权所有者，或其授权实体。

“法律实体”指行为实体及控制该实体、受该实体控制或与其受共同控制的所有实体。
“控制”指直接或间接通过合同或其他方式支配实体的管理，持有其至少百分之五十的股份，或享有其实益所有权。

“您”指行使本许可证所授权限的个人或法律实体。

“源码形式”指适合修改的形式，包括软件源代码、文档源文件和配置文件。

“目标形式”指对源码形式进行机械转换或翻译得到的形式，包括编译后的目标代码、生成的文档和其他媒体格式。

“作品”指以源码或目标形式提供、并通过附带版权声明表明采用本许可证的著作。

“衍生作品”指基于作品形成，且其编辑、注释、扩充或其他修改整体构成原创著作的作品。
仍可分离的作品，以及仅链接或按名称绑定作品或其衍生作品接口的作品，不属于此处的衍生作品。

“贡献”指版权所有者或其授权者有意提交给许可方，供纳入作品的原创作品，以及对作品或衍生作品的修改、补充。
“提交”包括发送给许可方或其代表的电子、口头或书面交流，包括项目邮件列表、源码管理系统和问题跟踪系统中的交流。
版权所有者明确以书面形式标为“不属于贡献”的交流不在此列。

“贡献者”指许可方，以及其贡献已被许可方接收并纳入作品的个人或法律实体。

#### 2. 版权许可

在遵守本许可证的前提下，每位贡献者授予您永久、全球、非独占、免费、免版税且不可撤销的版权许可，
允许以源码或目标形式复制作品、制作衍生作品、公开展示、公开表演、再许可及分发作品和衍生作品。

#### 3. 专利许可

在遵守本许可证的前提下，每位贡献者授予您永久、全球、非独占、免费、免版税的专利许可，
允许制造、委托制造、使用、许诺销售、销售、进口和以其他方式转让作品。
该许可仅涵盖贡献者有权许可，且其贡献本身或其贡献与所提交作品的组合必然涉及的专利权利要求。

如果您针对任何实体提起专利诉讼，包括反诉或交叉诉讼，主张作品或其中的贡献直接侵权或构成帮助侵权，
本许可证就该作品授予您的专利许可自提起诉讼之日起终止。

#### 4. 再分发

您可以通过任何媒体，以源码或目标形式，修改或不修改地复制和分发作品或衍生作品，但必须满足：

1. 向其他接收者提供本许可证的副本。
2. 在修改过的文件中显著说明您修改了该文件。
3. 分发衍生作品的源码时，保留原作品中的版权、专利、商标和署名声明，但与衍生作品无关的声明除外。
4. 如果原作品附带名为 `NOTICE` 的声明文件，分发衍生作品时必须提供其中相关署名声明的可读副本。
   可放在随附的声明文件、源码或文档中，或放在通常显示第三方声明的位置。
   声明文件仅用于提供信息，不改变许可证。您可增加自己的署名，但不得将其解释为修改本许可证。

您可以为自己的修改增加版权声明，也可以为自己的修改或衍生作品整体规定不同或附加的许可条件，
但您对原作品的使用、复制和分发仍须符合本许可证。

#### 5. 提交贡献

除非您明确另作声明，您有意提交给许可方以纳入作品的贡献均适用本许可证，不附加其他条件。
本条不取代您与许可方就贡献签订的单独协议。

#### 6. 商标

本许可证不授予使用许可方商号、商标、服务标记或产品名称的权利。
为合理、惯常地说明作品来源，以及复制声明文件内容所必需的使用除外。

#### 7. 免责声明

除非法律要求或另有书面约定，许可方及贡献者按“原样”提供作品和贡献，
不提供任何明示或默示保证，包括所有权、不侵权、适销性或特定用途适用性保证。
您自行判断使用或再分发作品是否适当，并承担行使本许可证权限所产生的风险。

#### 8. 责任限制

除非适用法律要求，例如故意或重大过失行为，或另有书面约定，
在任何法律理论下，包括侵权、合同或其他理论，贡献者均不对因本许可证、使用或无法使用作品造成的损害负责。
这包括直接、间接、特殊、附带或后果性损害，以及商誉损失、停工、计算机故障或失灵和其他商业损失，
即使贡献者已被告知可能发生这些损害也不例外。

#### 9. 接受担保或额外责任

分发作品或衍生作品时，您可以提供并收取支持、担保、赔偿或其他与本许可证一致的责任承诺的费用。
但您只能代表自己并自行负责，不得代表其他贡献者。
您必须同意就该承诺导致其他贡献者承担的责任或索赔，为其提供赔偿、抗辩并使其免受损害。

**条款结束。**

#### 附录：如何将 Apache 许可证用于您的作品

将以下声明附在作品中，并把方括号中的字段替换为您自己的信息，不保留方括号。
声明应采用适合文件格式的注释形式。建议同时写明文件名、类名和用途，便于第三方识别。

版权归属：[年份] [版权所有者姓名]

本作品采用 Apache 许可证 2.0 版。除非遵守该许可证，否则不得使用本文件。
您可以在 http://www.apache.org/licenses/LICENSE-2.0 获取许可证副本。
除非法律要求或另有书面约定，本作品按“原样”提供，不附带任何明示或默示保证。
有关具体权限和限制，请参阅许可证。

<details>
<summary>查看随附的英文许可证原文</summary>

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```

</details>
