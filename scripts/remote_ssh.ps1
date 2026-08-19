# ============================================================
# Windows → 魔力方舟快速 SSH 连接
#
# 用法:
#   .\scripts\remote_ssh.ps1 -ServerIP <公网IP>
#   .\scripts\remote_ssh.ps1 -ServerIP <公网IP> -Command "nvidia-smi"
# ============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,

    [string]$User = "root",

    [string]$Command = "",
    [string]$RemotePath = "/root/goai2026-robodojo"
)

if ($Command) {
    Write-Host ">>> ssh $User@$ServerIP '$Command'" -ForegroundColor DarkGray
    ssh "$User@$ServerIP" "cd $RemotePath && $Command"
} else {
    Write-Host ">>> ssh $User@$ServerIP (cd $RemotePath)" -ForegroundColor DarkGray
    ssh "$User@$ServerIP" "cd $RemotePath && bash"
}
