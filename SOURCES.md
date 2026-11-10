# 来源、版本与许可（SOURCES）

本仓库**不包含**任何第三方源代码。`install.ps1` 在安装时从下列上游仓库克隆，并按各上游许可证使用。

## 1. 上游清单

| 组件 | 上游仓库 | 版本 / 锁定 commit | 许可证 | 版权 | 用途 |
|---|---|---|---|---|---|
| `dsh-paper-studio` 插件 | https://github.com/liuhaolong16/dsh-paper-studio | v3.50.2 / `123ebc9b126137b8fc5e0d35d38f1f0072e361bb` | MIT | © 2026 liuhaolong16 | DSH 插件本体（`paper_studio` / `paper_dev`） |
| `research-paper-playbook` 判据资产 | https://github.com/liuhaolong16/research-paper-playbook | `0199091f370a6c2b34976f7c990956931490c2de` | MIT | © 2026 liuhaolong16 | 门脚本、短语库、论文方法论 |
| `paper-writing` skill | https://github.com/SNL-UCSB/paper-writing-skill | v3.0.1 / `676f8520bba54208eb4fe1d41620e365d9af6a24` | MIT | © 2026 Arpit Gupta | 科研论文写作流水线 |
| `tifs-tdsc-writing` skill | https://github.com/LazyDreamingDog/TIFS-TDSC-Writing | `be90d1ef51e33a9e7f0048316255647b831b1f9b` | **未声明**（README 仍为占位符） | 上游作者 | IEEE TIFS/TDSC 期刊风格 |
| `academic-paper-completion` / `skill-optimizer` skill | https://github.com/TohsakaRIN521/dsh-academic-skill | `592b1fc74e4633c219d0a1dcc9f88c369b7f5025` | **未声明** | 上游作者 | 论文补全与参考文献核验 |

> 未声明许可证的仓库默认保留所有权利。本仓库**不重新分发**它们的内容；`install.ps1` 只是在你自己的机器上从上游克隆并复制到本地 skill 目录。是否使用、如何再分发，请以各上游的授权为准。

## 2. 本套件对上游做的修改（全部在安装时本地完成）

1. **bundle 入口名修正**（`dsh-paper-studio`）
   - 文件：`plugin/cordis.patch.yml`
   - 原值：`name: dsh-paper-studio-v3`（嵌套包名，与整包安装名不一致）
   - 改为：`name: dsh-paper-studio`
   - 原因：否则 DSH 启动时 `ERR_MODULE_NOT_FOUND`，插件不激活。脚本幂等处理，上游若已修正则跳过。

2. **门脚本复制**（`dsh-paper-studio` → `research-paper-playbook`）
   - 把 `dsh-paper-studio/gates/` 下 12 个门脚本复制到 `playbook_root`。
   - 原因：CLI 只按 `playbook_root` 解析门路径；不复制时 9～10 道门会报「脚本不存在」。
   - 复制后 `doctor` 显示外部件与内置件摘要一致（无漂移）。

3. **本机路径表**（`~/.dsh/paper-studio/local-paths.json`）
   - 记录 `playbook_root`、`playbook_skill`、`python_exe`、`phrase_bank` 的真实路径。
   - 原因：上游真源用 `__LOCAL__/<key>` 占位符，缺少本机表时门会「未解析」失败。
   - 该文件在用户主目录，不入仓库、不随包分发。

4. **skill 落位**
   - 4 个 skill 复制到 `~/.dsh/skills/<name>/SKILL.md`（用户级根，rank 400），实现所有 profile/工作区全局可见。
   - 复制时删除 `.git`，不改变文件内容。

## 3. 版本漂移提醒

- 上游更新后，第 1 条修改可能已被上游修复（脚本会自动判断）；第 2 条若上游把门脚本并入 assets 或改为相对解析，脚本仍会复制但可能冗余。
- 锁定 commit 仅作记录，`install.ps1` 默认克隆各仓库默认分支的最新提交；需要完全复现时，可在克隆后手动 `git checkout <上表 commit>`。
- `dsh-paper-studio` 的入口名修正依赖其 `plugin/cordis.patch.yml` 结构；大版本升级后请重跑 `doctor` 与 `plugin/selftest.mjs`。

## 4. 安全说明

- 第三方插件**未经安全审计**。本地扫描对 `dsh-paper-studio@3.50.2` 的判定是 high=19 / medium=5，主要来自 CLI 编排器必需的 `child_process` 调用、`vm` 动态执行、以及读取自身密钥文件等；是否有可利用风险需按上游代码自行审查。
- 安装脚本不执行上游代码，只做克隆、复制、改一行 YAML、写本机路径表和调用 `dsh plugin add`。
- 建议在隔离环境先验证，再用于真实投稿流程。
