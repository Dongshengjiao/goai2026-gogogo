#!/usr/bin/env bash
# Policy Adapter 安装脚本
# 创建 conda 环境并安装策略依赖
set -euo pipefail

POLICY_ENV="${POLICY_ENV:-goai2026_policy}"

echo "=== Installing Policy Adapter ==="
echo "Conda env: ${POLICY_ENV}"

# 创建 conda 环境
if ! conda env list | grep -q "^${POLICY_ENV} "; then
    conda create -y -n "${POLICY_ENV}" python=3.10
fi
conda activate "${POLICY_ENV}"

# 安装策略依赖
pip install -e .

# 可选：安装 VLA 模型依赖
# pip install torch>=2.1 transformers>=4.36

echo "=== Policy Adapter installed ==="
echo "Activate with: conda activate ${POLICY_ENV}"
