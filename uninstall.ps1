#Requires -Version 5.1
<#
.SYNOPSIS
  卸载 dsh-paper-writing-kit 安装的内容。

.PARAMETER Profile
  要移除插件的 DSH profile。默认 desktop。

.PARAMETER Root
  套件安装根目录。默认 %USERPROFILE%\.dsh\paper-kit。

.PARAMETER DshCmd
  dsh 可执行文件路径。默认从 PATH 查找。

.PARAMETER PurgeVendor
  同时删除 Root\vendor 目录（上游克隆与补丁）。

.PARAMETER KeepSkills
  保留 4 个全局 skill。
#>
param(
  [string]$Profile = 'desktop',
  [string]$Root = (Join-Path $env:USERPROFILE '.dsh\paper-kit'),
  [string]$DshCmd = '',
  [switch]$PurgeVendor,
  [switch]$KeepSkills
)

$ErrorActionPreference = 'Continue'

function Write-Step([string]$msg) { Write-Host ("`n==> " + $msg) -ForegroundColor Cyan }
function Write-Ok([string]$msg) { Write-Host ("    OK  " + $msg) -ForegroundColor Green }
function Write-Warn2([string]$msg) { Write-Host ("    !!  " + $msg) -ForegroundColor Yellow }

function Resolve-Dsh([string]$explicit) {
  if ($explicit) {
    if (Test-Path $explicit) { return $explicit }
    Write-Warn2 ('指定的 dsh 路径不存在：' + $explicit)
    return $null
  }
  $cmd = Get-Command dsh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

Write-Step '1/4 从 profile 移除插件'
$dshPath = Resolve-Dsh -explicit $DshCmd
if ($dshPath) {
  & $dshPath plugin --profile $Profile remove dsh-paper-studio
  if ($LASTEXITCODE -eq 0) { Write-Ok '插件已移除' } else { Write-Warn2 '插件移除返回非零（可能本来未安装），继续' }
}
else {
  Write-Warn2 '未找到 dsh，跳过插件移除；请手动执行：dsh plugin --profile <p> remove dsh-paper-studio'
}

Write-Step '2/4 移除本机路径表'
$localPaths = Join-Path $env:USERPROFILE '.dsh\paper-studio\local-paths.json'
if (Test-Path $localPaths) {
  Remove-Item $localPaths -Force
  Write-Ok ('已删除 ' + $localPaths)
}
else {
  Write-Ok '本机路径表不存在，跳过'
}

Write-Step '3/4 移除 4 个全局 skill'
if ($KeepSkills) {
  Write-Warn2 '按参数保留 skill（-KeepSkills）'
}
else {
  $skillsRoot = Join-Path $env:USERPROFILE '.dsh\skills'
  foreach ($name in @('paper-writing', 'tifs-tdsc-writing', 'academic-paper-completion', 'skill-optimizer')) {
    $p = Join-Path $skillsRoot $name
    if (Test-Path $p) {
      Remove-Item $p -Recurse -Force
      Write-Ok ('已删除 skill：' + $p)
    }
    else {
      Write-Ok ('skill 不存在，跳过：' + $name)
    }
  }
}

Write-Step '4/4 清理 vendor'
if ($PurgeVendor) {
  if (Test-Path $Root) {
    Remove-Item $Root -Recurse -Force
    Write-Ok ('已删除 ' + $Root)
  }
  else {
    Write-Ok '安装根目录不存在，跳过'
  }
}
else {
  Write-Warn2 ('保留安装目录（如需删除请加 -PurgeVendor）：' + $Root)
}

Write-Host ''
Write-Host '卸载完成。请重启 DeepSeek Harness。' -ForegroundColor Green
