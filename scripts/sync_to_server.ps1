# ============================================================
# Windows → 魔力方舟远程服务器同步脚本
#
# 用法:
#   .\scripts\sync_to_server.ps1 -ServerIP <公网IP> -User root
#
# 功能:
#   1. 将本地项目代码上传到远程服务器
#   2. 远程执行部署脚本
#   3. 支持只同步代码（不重新安装环境）
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,

    [string]$User = "root",

    [string]$RemotePath = "/root/goai2026-robodojo",

    [switch]$Deploy,        # 执行完整部署
    [switch]$CodeOnly,      # 只同步代码（不同步 RoboDojo/）
    [switch]$SmokeTest      # 同步后执行冒烟测试
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  GOAI 2026 · Windows → 魔力方舟同步" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Server:    $($User)@$($ServerIP)"
Write-Host "  RemoteDir: $RemotePath"
Write-Host ""

# 确保 scp 可用
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: scp 不可用。Windows 10+ 自带 OpenSSH，请确认已安装。" -ForegroundColor Red
    exit 1
}

# 同步代码
Write-Host "[1/3] 同步项目代码到远程服务器..." -ForegroundColor Yellow

$excludeArgs = @(
    "--exclude=RoboDojo",
    "--exclude=*.pyc",
    "--exclude=__pycache__",
    "--exclude=.git",
    "--exclude=checkpoints",
    "--exclude=eval_result",
    "--exclude=benchmark_results"
)

if ($CodeOnly) {
    $excludeArgs += @("--exclude=data", "--exclude=Assets")
}

$scpCmd = "scp -r $($excludeArgs -join ' ') ./* $($User)@$($ServerIP):$RemotePath/"
Write-Host "  $scpCmd"
Invoke-Expression $scpCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: 同步失败" -ForegroundColor Red
    exit 1
}
Write-Host "  同步完成。" -ForegroundColor Green
Write-Host ""

# 远程部署
if ($Deploy) {
    Write-Host "[2/3] 远程执行部署脚本..." -ForegroundColor Yellow
    $deployCmd = "ssh $($User)@$($ServerIP) 'cd $RemotePath && bash scripts/deploy_molifangzhou.sh'"
    Write-Host "  $deployCmd"
    Invoke-Expression $deployCmd

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: 部署失败" -ForegroundColor Red
        exit 1
    }
    Write-Host "  部署完成。" -ForegroundColor Green
} else {
    Write-Host "[2/3] 跳过部署（-Deploy 启用完整部署）" -ForegroundColor DarkGray
}
Write-Host ""

# 冒烟测试
if ($SmokeTest) {
    Write-Host "[3/3] 远程执行冒烟测试..." -ForegroundColor Yellow
    $smokeCmd = "ssh $($User)@$($ServerIP) 'cd $RemotePath && bash scripts/smoke_test.sh'"
    Write-Host "  $smokeCmd"
    Invoke-Expression $smokeCmd
    Write-Host ""
} else {
    Write-Host "[3/3] 跳过冒烟测试（-SmokeTest 启用）" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  完成！" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  服务器项目路径: $RemotePath"
Write-Host "  SSH 连接:        ssh $User@$ServerIP"
Write-Host "  启动服务:         ssh $User@$ServerIP 'cd $RemotePath && bash scripts/start_policy_server.sh'"
Write-Host "============================================================" -ForegroundColor Cyan
