#Requires -Version 5.1
<#
.SYNOPSIS
  安装 dsh-paper-writing-kit：dsh-paper-studio 插件 + 4 个写作 skill + 判据资产。

.DESCRIPTION
  1) 从上游克隆 5 个仓库到 Root\vendor（GitHub 直连失败时回退 gh-proxy 镜像）；
  2) 修正 dsh-paper-studio 的 bundle 入口名；
  3) 把插件自带 gates/ 的门脚本复制到 playbook_root；
  4) 写入 ~/.dsh/paper-studio/local-paths.json；
  5) 把 4 个 skill 复制到 ~/.dsh/skills；
  6) 执行 dsh plugin --profile <Profile> add link:<插件目录>。

.PARAMETER Profile
  目标 DSH profile。默认 desktop（Electron 桌面端）；CLI 用户通常传 web。

.PARAMETER Root
  本套件安装根目录。默认 %USERPROFILE%\.dsh\paper-kit。

.PARAMETER DshCmd
  dsh 可执行文件路径。默认从 PATH 查找；找不到时请传本机路径。

.PARAMETER SkipPlugin
  只安装 4 个 skill，不安装插件。

.PARAMETER NoProxyFallback
  克隆失败时不回退 gh-proxy.com 镜像。
#>
param(
  [string]$Profile = 'desktop',
  [string]$Root = (Join-Path $env:USERPROFILE '.dsh\paper-kit'),
  [string]$DshCmd = '',
  [switch]$SkipPlugin,
  [switch]$NoProxyFallback
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:GIT_TERMINAL_PROMPT = '0'

function Write-Step([string]$msg) { Write-Host ("`n==> " + $msg) -ForegroundColor Cyan }
function Write-Ok([string]$msg) { Write-Host ("    OK  " + $msg) -ForegroundColor Green }
function Write-Warn2([string]$msg) { Write-Host ("    !!  " + $msg) -ForegroundColor Yellow }

$repos = @(
  [pscustomobject]@{ Name = 'dsh-paper-studio'; Url = 'https://github.com/liuhaolong16/dsh-paper-studio.git' },
  [pscustomobject]@{ Name = 'research-paper-playbook'; Url = 'https://github.com/liuhaolong16/research-paper-playbook.git' },
  [pscustomobject]@{ Name = 'paper-writing-skill'; Url = 'https://github.com/SNL-UCSB/paper-writing-skill.git' },
  [pscustomobject]@{ Name = 'TIFS-TDSC-Writing'; Url = 'https://github.com/LazyDreamingDog/TIFS-TDSC-Writing.git' },
  [pscustomobject]@{ Name = 'dsh-academic-skill'; Url = 'https://github.com/TohsakaRIN521/dsh-academic-skill.git' }
)

function Assert-Git {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { throw '未找到 git。请先安装 Git for Windows 并确保 git 在 PATH 中。' }
  Write-Ok 'git 可用'
}

function Invoke-CloneAttempt([string[]]$gitArgs, [string]$dest) {
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
  & git @gitArgs 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) { return $false }
  return (Test-Path (Join-Path $dest '.git'))
}

function Install-Repo([string]$url, [string]$dest) {
  if (Test-Path (Join-Path $dest '.git')) {
    Write-Ok ('已存在，跳过克隆：' + $dest)
    return
  }
  $base = @('-c', 'http.lowSpeedLimit=1000', '-c', 'http.lowSpeedTime=20')
  $attempts = New-Object System.Collections.ArrayList

  [void]$attempts.Add($base + @('clone', '--depth', '1', $url, $dest))
  [void]$attempts.Add($base + @('-c', 'http.sslBackend=openssl', 'clone', '--depth', '1', $url, $dest))
  if (-not $NoProxyFallback) {
    $mirror = 'https://gh-proxy.com/' + $url
    [void]$attempts.Add($base + @('clone', '--depth', '1', $mirror, $dest))
    [void]$attempts.Add($base + @('-c', 'http.sslBackend=openssl', 'clone', '--depth', '1', $mirror, $dest))
  }

  foreach ($gitAttempt in $attempts) {
    $label = ($gitAttempt -join ' ')
    if ($label -match 'gh-proxy\.com') { $label = $label -replace 'https://gh-proxy\.com/https://github\.com/', 'gh-proxy:' }
    Write-Host ('    尝试：git ' + $label)
    if (Invoke-CloneAttempt -gitArgs $gitAttempt -dest $dest) {
      Write-Ok ('克隆成功：' + $dest)
      return
    }
  }
  throw ('克隆失败：' + $url + '（已尝试直连与镜像回退）')
}

function Set-BundleEntryName([string]$studioDir) {
  $patch = Join-Path $studioDir 'plugin\cordis.patch.yml'
  if (-not (Test-Path $patch)) {
    Write-Warn2 ('未找到 ' + $patch + '，跳过入口名修正')
    return
  }
  $txt = [System.IO.File]::ReadAllText($patch)
  if ($txt -match 'name:\s*dsh-paper-studio-v3') {
    $txt = $txt -replace 'name:\s*dsh-paper-studio-v3', 'name: dsh-paper-studio'
    [System.IO.File]::WriteAllText($patch, $txt, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok '已修正 bundle 入口名：dsh-paper-studio-v3 -> dsh-paper-studio'
  }
  else {
    Write-Ok 'bundle 入口名无需修正（上游可能已修复）'
  }
}

function Copy-GateScripts([string]$studioDir, [string]$playbookDir) {
  $src = Join-Path $studioDir 'gates'
  if (-not (Test-Path $src)) {
    Write-Warn2 '插件未自带 gates/ 目录，跳过门脚本复制'
    return
  }
  Copy-Item (Join-Path $src '*') $playbookDir -Force
  Write-Ok ('已把门脚本复制到 playbook_root：' + $playbookDir)
}

function Write-LocalPaths([string]$playbookDir) {
  $dir = Join-Path $env:USERPROFILE '.dsh\paper-studio'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $python = ''
  foreach ($candidate in @('python', 'python3', 'py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source; break }
  }
  if (-not $python) { Write-Warn2 '未找到 python，python_exe 留空；需要 Python 门时请手动补 local-paths.json' }
  $obj = [ordered]@{
    playbook_root  = $playbookDir
    playbook_skill = (Join-Path $playbookDir 'SKILL.md')
    writer_skill   = ''
    polish_skill   = ''
    python_exe     = [string]$python
    phrase_bank    = (Join-Path $playbookDir '_assertions-digest.json')
  }
  $file = Join-Path $dir 'local-paths.json'
  [System.IO.File]::WriteAllText($file, ($obj | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
  Write-Ok ('已写入本机路径表：' + $file)
}

function Install-Skills([string]$vendorDir) {
  $skillsRoot = Join-Path $env:USERPROFILE '.dsh\skills'
  New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
  $map = @(
    [pscustomobject]@{ Name = 'paper-writing'; Src = (Join-Path $vendorDir 'paper-writing-skill') },
    [pscustomobject]@{ Name = 'tifs-tdsc-writing'; Src = (Join-Path $vendorDir 'TIFS-TDSC-Writing') },
    [pscustomobject]@{ Name = 'academic-paper-completion'; Src = (Join-Path $vendorDir 'dsh-academic-skill\academic-paper-completion') },
    [pscustomobject]@{ Name = 'skill-optimizer'; Src = (Join-Path $vendorDir 'dsh-academic-skill\skill-optimizer') }
  )
  foreach ($m in $map) {
    if (-not (Test-Path $m.Src)) { Write-Warn2 ('来源缺失，跳过：' + $m.Name); continue }
    $dest = Join-Path $skillsRoot $m.Name
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $m.Src $dest -Recurse -Force
    Remove-Item (Join-Path $dest '.git') -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path (Join-Path $dest 'SKILL.md')) {
      Write-Ok ('skill 已安装：' + $dest)
    }
    else {
      Write-Warn2 ('已复制但缺少 SKILL.md，请检查来源：' + $m.Src)
    }
  }
}

function Resolve-Dsh([string]$explicit) {
  if ($explicit) {
    if (Test-Path $explicit) { return $explicit }
    throw ('指定的 dsh 路径不存在：' + $explicit)
  }
  $cmd = Get-Command dsh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  throw '未找到 dsh 命令。请把 DSH CLI 加入 PATH，或用 -DshCmd 指定（Electron 版一般在 D:\deepseek\resources\runtime\cli\bin\dsh.cmd）。'
}

# ---------------- main ----------------

Write-Step '0/6 检查前置条件'
Assert-Git

$vendor = Join-Path $Root 'vendor'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null

Write-Step ('1/6 克隆上游仓库到 ' + $vendor)
foreach ($r in $repos) {
  Install-Repo -url $r.Url -dest (Join-Path $vendor $r.Name)
}

$studio = Join-Path $vendor 'dsh-paper-studio'
$playbook = Join-Path $vendor 'research-paper-playbook'

Write-Step '2/6 修正 bundle 入口名'
Set-BundleEntryName -studioDir $studio

Write-Step '3/6 对齐门脚本'
Copy-GateScripts -studioDir $studio -playbookDir $playbook

Write-Step '4/6 写入本机路径表'
Write-LocalPaths -playbookDir $playbook

Write-Step '5/6 安装 4 个全局 skill'
Install-Skills -vendorDir $vendor

Write-Step '6/6 安装 DSH 插件'
if ($SkipPlugin) {
  Write-Warn2 '按参数跳过插件安装（-SkipPlugin）'
}
else {
  $dshPath = Resolve-Dsh -explicit $DshCmd
  & $dshPath plugin --profile $Profile add ('link:' + $studio)
  if ($LASTEXITCODE -ne 0) { throw ('插件安装失败（profile=' + $Profile + '）') }
  Write-Ok ('插件已注册到 profile：' + $Profile)
}

Write-Step '自检'
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  Push-Location $studio
  try {
    node bin\studio.cjs doctor 2>&1 | Select-Object -Last 6 | ForEach-Object { Write-Host ('    ' + $_) }
  }
  finally { Pop-Location }
}
else {
  Write-Warn2 '未找到 node，跳过自检'
}

Write-Host ''
Write-Host '安装完成。请重启 DeepSeek Harness 后在新会话中验证：' -ForegroundColor Green
Write-Host '  - 工具列表出现 paper_studio / paper_dev'
Write-Host '  - 技能目录出现 paper-writing / tifs-tdsc-writing / academic-paper-completion / skill-optimizer'
Write-Host ('  - 插件目录：' + $studio)
Write-Host '卸载：.\uninstall.ps1'
