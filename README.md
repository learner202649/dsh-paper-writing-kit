# dsh-paper-writing-kit

一键把「期刊论文写作」能力装进 [DeepSeek Harness (DSH)](https://github.com/deepseek-ai/deepseek-harness)：**1 个论文插件 + 4 个写作 skill + 12 道机器门 + 期刊判据资产**。

> 本仓库只包含**安装脚本与文档**，不包含任何第三方代码。安装时按下面锁定的上游来源克隆，许可证与版权归各上游作者所有。

---

## 1. 它装了什么

| 组件 | 类型 | 作用 |
|---|---|---|
| `dsh-paper-studio`（V3） | DSH 插件 | 5 种写作模式、47 个子命令、12 道门、期刊路由、投稿合规/声明/参考文献核验 |
| `paper-writing` | 全局 skill | 科研论文五阶段流水线、分节修辞、风格门、红队评审 |
| `tifs-tdsc-writing` | 全局 skill | IEEE TIFS / TDSC 期刊风格润色与大纲 |
| `academic-paper-completion` | 全局 skill | 初稿补全 + 参考文献真实性核验（arXiv TeX 流程，Python 脚本） |
| `skill-optimizer` | 全局 skill | 把重复流程固化为 skill（作者配套工具） |
| `research-paper-playbook` | 判据资产 | paper-studio 的门脚本、短语库与论文方法论 |

安装后你会得到：

- 会话里的两个插件工具：`paper_studio`（唯一使用入口）与 `paper_dev`（开发者模式，默认封闭）；
- 技能目录里的 4 个全局 skill（可用 `/paper-writing` 显式调用，也可被模型自动加载）；
- `doctor` 自检：门 **12/12**、素材 **6/6**。

## 2. 全局可用性（重要）

| 范围 | 结论 |
|---|---|
| **插件** | **profile 级**：装进某个 profile（默认 `desktop`）后，该 profile 下的**所有会话、所有工作区**都能用；换到别的 profile 需要再装一次。 |
| **skill** | **用户级**：装进 `~/.dsh/skills` 后，**所有 profile、所有工作区、新开对话**都可见。 |
| **跨机器** | 本机路径（插件目录、playbook、Python）记录在 `~/.dsh/paper-studio/local-paths.json`，因此**换机器/移动目录要重新跑一次 `install.ps1`**。 |

所以：同一台机器上，装一次即可全局使用；要复制到别的机器，直接用本套件重装。

## 3. 安装

### 前置条件

- Windows + PowerShell 5.1 及以上；
- Git（`git` 在 PATH 中）；
- Node.js ≥ 20；
- `dsh` 命令。Electron 桌面端的 CLI 一般在 `D:\deepseek\resources\runtime\cli\bin\dsh.cmd`，不在 PATH 时用 `-DshCmd` 指定。

### 一条命令

```powershell
git clone https://github.com/<你的用户名>/dsh-paper-writing-kit.git
cd dsh-paper-writing-kit
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

默认参数：`-Profile desktop`、`-Root "$env:USERPROFILE\.dsh\paper-kit"`。

常用参数：

```powershell
# 指定 profile（CLI 用户通常是 web）
.\install.ps1 -Profile web

# 自定义 dsh 可执行文件
.\install.ps1 -DshCmd "D:\deepseek\resources\runtime\cli\bin\dsh.cmd"

# 只装 4 个 skill，不装插件
.\install.ps1 -SkipPlugin

# 不尝试 gh-proxy 镜像回退（GitHub 直连正常时）
.\install.ps1 -NoProxyFallback
```

安装完成后：**重启 DeepSeek Harness**。之后新会话里会出现 `paper_studio` / `paper_dev` 工具。

### 验证

```powershell
# 环境自检（应显示 门 12/12、素材 6/6）
node "$env:USERPROFILE\.dsh\paper-kit\vendor\dsh-paper-studio\bin\studio.cjs" doctor

# 插件自检（40 项）
node "$env:USERPROFILE\.dsh\paper-kit\vendor\dsh-paper-studio\plugin\selftest.mjs"
```

## 4. 使用

在会话里直接说「帮我写论文 / 润色这篇稿子 / 做投稿前体检」，模型会调用 `paper_studio`。

常用动作：

```text
paper_studio action=modes                 # 五模式菜单（用可点击选项呈现）
paper_studio action=intent text=<用户原话>  # 确定性判断“是不是论文请求”
paper_studio action=route args=["把这篇稿子按中文核心期刊要求改一遍"]
paper_studio action=sections args=["--genre","research"]
paper_studio action=stylecheck args=["--draft","路径/稿.md"]
paper_studio action=doctor                # 环境与门自检
paper_studio action=audit                 # 出厂审查
```

开发者模式（改判据资产）：`paper_dev action=status|list|read`；写入需用用户原话解锁：`paper_dev action=unlock phrase="进入论文插件开发者模式"`。

## 5. 安装脚本做了什么

1. 按锁定来源克隆 5 个上游仓库到 `Root\vendor`（GitHub 直连失败时自动回退 `gh-proxy.com` 镜像）；
2. 修正 `dsh-paper-studio` 的 bundle 入口名（上游 v3.50.2 的 `dsh-paper-studio-v3` 与安装包名不一致，会导致 `ERR_MODULE_NOT_FOUND`）；
3. 把插件自带 `gates/` 的 12 个门脚本复制到 `playbook_root`（CLI 只按 `playbook_root` 解析门路径）；
4. 写入 `~/.dsh/paper-studio/local-paths.json`（playbook、Python、短语库路径）；
5. 把 5 个上游 skill 源复制为 4 个全局 skill 到 `~/.dsh/skills`（去重 `.git`）；
6. 执行 `dsh plugin --profile <p> add link:<插件目录>`，把插件注册进 profile。

## 6. 已知限制

- 门是**机械检查**（正则/启发式），语义判断仍需跨模型 reviewer 与人工；
- 判据资产偏中文核心期刊、PLOS、Elsevier；其他刊物需自行补 `references/contracts/*.json`；
- 第三方插件**未经安全审计**，请自行评估后使用（上游项目、版本、许可证见 [SOURCES.md](SOURCES.md)）；
- 上游在演进：脚本对入口名修正是幂等的，但上游若大改结构，可能需要同步调整；
- 不支持只装 `plugin/` 单目录（缺仓库根的 `references/`，插件会显形失败）。

## 7. 来源与许可

详见 [SOURCES.md](SOURCES.md)。摘要：

- 插件与判据资产：`liuhaolong16/dsh-paper-studio`、`liuhaolong16/research-paper-playbook`（MIT）；
- `paper-writing` skill：`SNL-UCSB/paper-writing-skill`（MIT，© Arpit Gupta）；
- `tifs-tdsc-writing` skill：`LazyDreamingDog/TIFS-TDSC-Writing`（上游未声明许可证）；
- `academic-paper-completion`、`skill-optimizer`：`TohsakaRIN521/dsh-academic-skill`（上游未声明许可证）。

本仓库自身的脚本与文档以 MIT 发布；**不重新分发上述第三方代码**，安装时从上游获取。

## 8. 卸载

```powershell
.\uninstall.ps1                      # 移除插件与 skill，保留 vendor 目录
.\uninstall.ps1 -PurgeVendor         # 同时删除 Root\vendor
```

卸载后同样需要重启 DeepSeek Harness。

## 9. 目录结构

```
dsh-paper-writing-kit/
├── install.ps1          # 安装脚本
├── uninstall.ps1        # 卸载脚本
├── SOURCES.md           # 上游来源、版本、许可证与修改说明
├── vendor-sources.json  # 机器可读的来源锁定表
├── LICENSE              # 本仓库脚本/文档的 MIT 许可
└── README.md
```
