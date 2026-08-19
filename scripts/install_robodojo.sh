#!/usr/bin/env bash
# ============================================================
# RoboDojo + XPolicyLab 一键安装
# 系统要求: Ubuntu 22.04, NVIDIA GPU >= 16GB VRAM, CUDA 12.8
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "============================================================"
echo "  GOAI 2026 RoboDojo Installation"
echo "============================================================"
echo "  Repo root: ${REPO_ROOT}"
echo ""

# 1. 克隆 RoboDojo（含 XPolicyLab 子模块）
ROBODOJO_DIR="${REPO_ROOT}/RoboDojo"
if [ ! -d "${ROBODOJO_DIR}" ]; then
    echo "[1/5] Cloning RoboDojo..."
    git lfs install
    git clone --recurse-submodules https://github.com/RoboDojo-Benchmark/RoboDojo.git "${ROBODOJO_DIR}"
else
    echo "[1/5] RoboDojo already exists, updating submodules..."
    cd "${ROBODOJO_DIR}"
    git submodule update --init --recursive
fi

# 2. 安装 RoboDojo（Isaac Sim 5.1 + Isaac Lab + CuRobo）
echo "[2/5] Running RoboDojo install script..."
cd "${ROBODOJO_DIR}"
if [ ! -d "${HOME}/miniforge3/envs/RoboDojo" ] && [ ! -d "${HOME}/anaconda3/envs/RoboDojo" ]; then
    bash scripts/install.sh -i
else
    echo "  RoboDojo conda env already exists, skipping."
fi

# 3. 下载 GOAI 专用资源
echo "[3/5] Downloading GOAI-2026 assets..."
bash "${SCRIPT_DIR}/download_assets.sh"

# 4. 更新本体路径
echo "[4/5] Updating embodiment config paths..."
cd "${ROBODOJO_DIR}"
conda run -n RoboDojo python utils/update_embodiment_config_path.py

# 5. 安装 Policy Adapter
echo "[5/5] Installing Policy Adapter..."
cd "${REPO_ROOT}"
pip install -e .

echo ""
echo "============================================================"
echo "  Installation complete!"
echo "  Activate: conda activate RoboDojo"
echo "  Smoke test: bash scripts/smoke_test.sh"
echo "============================================================"
