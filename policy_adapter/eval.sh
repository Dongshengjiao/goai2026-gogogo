#!/usr/bin/env bash
# 同机评测脚本
# 用法:
#   bash eval.sh <bench_name> <task_name> <ckpt_name> <env_cfg_type> \
#               <action_type> <seed> <policy_gpu_id> <env_gpu_id> \
#               <policy_conda_env> <eval_env_conda_env>
#
# 示例:
#   bash eval.sh RoboDojo stack_bowls demo arx_x5 ee 0 0 0 goai2026_policy RoboDojo
set -euo pipefail

BENCH_NAME="${1:-RoboDojo}"
TASK_NAME="${2:-stack_bowls}"
CKPT_NAME="${3:-demo}"
ENV_CFG_TYPE="${4:-arx_x5}"
ACTION_TYPE="${5:-ee}"
SEED="${6:-0}"
POLICY_GPU_ID="${7:-0}"
ENV_GPU_ID="${8:-0}"
POLICY_ENV="${9:-goai2026_policy}"
EVAL_ENV="${10:-RoboDojo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
ROBODOJO_ROOT="${ROBODOJO_ROOT:-${REPO_ROOT}/RoboDojo}"

echo "=== GOAI 2026 Eval ==="
echo "  bench:       ${BENCH_NAME}"
echo "  task:        ${TASK_NAME}"
echo "  ckpt:        ${CKPT_NAME}"
echo "  env_cfg:     ${ENV_CFG_TYPE}"
echo "  action_type: ${ACTION_TYPE}"
echo "  seed:        ${SEED}"
echo "  policy_gpu:  ${POLICY_GPU_ID}"
echo "  env_gpu:     ${ENV_GPU_ID}"

# 启动 Policy Server
bash "${SCRIPT_DIR}/setup_eval_policy_server.sh" \
    "${BENCH_NAME}" "${TASK_NAME}" "${CKPT_NAME}" "${ENV_CFG_TYPE}" \
    "${ACTION_TYPE}" "${SEED}" "${POLICY_GPU_ID}" "${POLICY_ENV}" \
    9999 "127.0.0.1" &
POLICY_PID=$!
echo "Policy server PID: ${POLICY_PID}"

# 等待 Policy Server 就绪
sleep 5

# 启动环境客户端（调用 RoboDojo 评测脚本）
if [ -f "${ROBODOJO_ROOT}/scripts/robodojo.sh" ]; then
    bash "${ROBODOJO_ROOT}/scripts/robodojo.sh" client \
        --task "${TASK_NAME}" \
        --policy-name "goai2026_policy" \
        --policy-host 127.0.0.1 \
        --policy-port 9999 \
        --ckpt "${CKPT_NAME}" \
        --eval-num 1 \
        --action-type "${ACTION_TYPE}"
else
    echo "RoboDojo not found at ${ROBODOJO_ROOT}"
    echo "Run scripts/install_robodojo.sh first"
    kill "${POLICY_PID}" 2>/dev/null || true
    exit 1
fi

# 清理
kill "${POLICY_PID}" 2>/dev/null || true
echo "=== Eval complete ==="
