#!/usr/bin/env bash
# ============================================================
# 启动公网 Policy Server（用于官方评测提交）
#
# 使用前：
#   1. 确保 RoboDojo 已安装（scripts/install_robodojo.sh）
#   2. 确保 9999 端口公网可达（配置防火墙/端口映射/反向代理）
#   3. 建议使用固定公网 IP 或域名
#   4. 建议启用 TLS（wss://），可用 nginx 反向代理
#
# 提交时在 https://xsparkai.com/goai-2026/apply 填写：
#   协议: wss
#   主机: 你的公网 IP 或域名
#   端口: 9999
#   策略名: goai2026_policy
#   动作类型: ee（或 joint，须与本地一致）
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
POLICY_DIR="${REPO_ROOT}/policy_adapter"

# 参数
PORT="${PORT:-9999}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"
ACTION_TYPE="${ACTION_TYPE:-ee}"
CKPT_NAME="${CKPT_NAME:-demo}"
GPU_ID="${GPU_ID:-0}"
POLICY_ENV="${POLICY_ENV:-goai2026_policy}"

echo "============================================================"
echo "  Starting Public Policy Server"
echo "============================================================"
echo "  bind:        ${BIND_HOST}:${PORT}"
echo "  action_type: ${ACTION_TYPE}"
echo "  ckpt:        ${CKPT_NAME}"
echo "  gpu:         ${GPU_ID}"
echo ""
echo "  Submit to https://xsparkai.com/goai-2026/apply with:"
echo "    protocol: wss"
echo "    host:     <YOUR_PUBLIC_IP>"
echo "    port:     ${PORT}"
echo "============================================================"

export CUDA_VISIBLE_DEVICES="${GPU_ID}"

bash "${POLICY_DIR}/setup_eval_policy_server.sh" \
    RoboDojo all "${CKPT_NAME}" arx_x5 "${ACTION_TYPE}" 0 \
    "${GPU_ID}" "${POLICY_ENV}" "${PORT}" "${BIND_HOST}"
