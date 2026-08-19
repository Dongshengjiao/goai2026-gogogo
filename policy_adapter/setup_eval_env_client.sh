#!/usr/bin/env bash
# 环境客户端启动脚本（仿真端）
# 用法:
#   bash setup_eval_env_client.sh <bench_name> <task_name> <ckpt_name> \
#       <env_cfg_type> <action_type> <seed> <env_gpu_id> \
#       <eval_env> <additional_info> <port> <policy_server_ip>
set -euo pipefail

BENCH_NAME="${1:-RoboDojo}"
TASK_NAME="${2:-stack_bowls}"
CKPT_NAME="${3:-demo}"
ENV_CFG_TYPE="${4:-arx_x5}"
ACTION_TYPE="${5:-ee}"
SEED="${6:-0}"
ENV_GPU_ID="${7:-0}"
EVAL_ENV="${8:-RoboDojo}"
ADDITIONAL_INFO="${9:-}"
PORT="${10:-9999}"
POLICY_SERVER_IP="${11:-127.0.0.1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
ROBODOJO_ROOT="${ROBODOJO_ROOT:-${REPO_ROOT}/RoboDojo}"

echo "=== Starting Environment Client ==="
echo "  task:          ${TASK_NAME}"
echo "  policy_server: ${POLICY_SERVER_IP}:${PORT}"
echo "  env_gpu:       ${ENV_GPU_ID}"

export CUDA_VISIBLE_DEVICES="${ENV_GPU_ID}"

if [ ! -f "${ROBODOJO_ROOT}/scripts/robodojo.sh" ]; then
    echo "ERROR: RoboDojo not found at ${ROBODOJO_ROOT}"
    echo "Run scripts/install_robodojo.sh first"
    exit 1
fi

bash "${ROBODOJO_ROOT}/scripts/robodojo.sh" client \
    --task "${TASK_NAME}" \
    --policy-name "goai2026_policy" \
    --policy-host "${POLICY_SERVER_IP}" \
    --policy-port "${PORT}" \
    --ckpt "${CKPT_NAME}" \
    --action-type "${ACTION_TYPE}" \
    --eval-num 1
