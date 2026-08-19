#!/usr/bin/env bash
# ============================================================
# 下载 GOAI-2026 专用资源和数据
# 默认使用 ModelScope（国内网络更快），可通过 USE_MIRROR=hf 切换
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
ROBODOJO_DIR="${REPO_ROOT}/RoboDojo"
USE_MIRROR="${USE_MIRROR:-modelscope}"  # 默认 modelscope（国内加速）
SKIP_DATA="${SKIP_DATA:-0}"  # SKIP_DATA=1 跳过 hdf5 训练数据（评测不需要）

echo "=== Downloading GOAI-2026 Assets (mirror: ${USE_MIRROR}) ==="

cd "${ROBODOJO_DIR}"

if [ "${USE_MIRROR}" = "modelscope" ]; then
    pip install -U modelscope
    echo "Using ModelScope (国内加速)..."

    # 下载资产（Assets 目录）
    modelscope download --dataset RoboDojo-Benchmark/GOAI-2026 \
        --include "Assets/**" \
        --local_dir .

    # 下载数据（HDF5 格式，用于训练，评测不需要）
    if [ "${SKIP_DATA}" != "1" ]; then
        modelscope download --dataset RoboDojo-Benchmark/GOAI-2026 \
            --include "data/hdf5/**" \
            --local_dir .
    else
        echo "  SKIP_DATA=1, 跳过 hdf5 训练数据（评测不需要）。"
    fi
else
    pip install -U huggingface_hub
    echo "Using HuggingFace..."

    # 下载资产
    hf download RoboDojo-Benchmark/GOAI-2026 \
        --repo-type dataset \
        --include "Assets/**" \
        --local-dir .

    # 下载数据（HDF5 格式）
    hf download RoboDojo-Benchmark/GOAI-2026 \
        --repo-type dataset \
        --include "data/hdf5/**" \
        --local-dir .
fi

echo "=== Assets downloaded ==="
echo "Assets directory:"
ls -lh "${ROBODOJO_DIR}/Assets/" 2>/dev/null || echo "  Assets dir not found, check download."
echo "Data directory:"
ls -lh "${ROBODOJO_DIR}/data/" 2>/dev/null || echo "  data dir not found, check download."
