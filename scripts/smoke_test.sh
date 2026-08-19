#!/usr/bin/env bash
# ============================================================
# 冒烟测试：验证 24 个配置的端到端链路
# 官方命令: bash scripts/robodojo.sh smoke --dimension generalization ...
# 冒烟测试仅验证链路可通，不代表正式成绩。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
ROBODOJO_DIR="${REPO_ROOT}/RoboDojo"
POLICY_DIR="${REPO_ROOT}/policy_adapter"
POLICY_ENV="${POLICY_ENV:-goai2026_policy}"
EVAL_ENV="${EVAL_ENV:-RoboDojo}"
ACTION_TYPE="${ACTION_TYPE:-ee}"
RUN_LABEL="${RUN_LABEL:-demo}"

echo "============================================================"
echo "  GOAI 2026 Smoke Test"
echo "============================================================"
echo "  action_type: ${ACTION_TYPE}"
echo "  run_label:   ${RUN_LABEL}"
echo "  policy_env:  ${POLICY_ENV}"
echo ""

if [ ! -f "${ROBODOJO_DIR}/scripts/robodojo.sh" ]; then
    echo "ERROR: RoboDojo not found. Run scripts/install_robodojo.sh first."
    exit 1
fi

cd "${ROBODOJO_DIR}"

echo "Running official smoke test (24 configs x 1 episode)..."
bash scripts/robodojo.sh smoke \
    --dimension generalization \
    --policy-dir "${POLICY_DIR}" \
    --ckpt "${RUN_LABEL}" \
    --policy-env "${POLICY_ENV}" \
    --eval-env "${EVAL_ENV}" \
    --action-type "${ACTION_TYPE}" \
    --eval-num 1

echo ""
echo "============================================================"
echo "  Smoke test complete!"
echo "  Check eval_result/ for results."
echo "  Note: success_rate=0.0 is expected for demo policy."
echo "  This test verifies the end-to-end pipeline, not scores."
echo "============================================================"
