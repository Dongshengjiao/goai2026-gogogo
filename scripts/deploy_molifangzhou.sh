#!/usr/bin/env bash
# ============================================================
# 魔力方舟 GPU 云服务器专用部署脚本
#
# 适用环境:
#   - 魔力方舟租用的 RTX 4090 24GB 服务器
#   - PyTorch 镜像 (Python 3.12 + CUDA 12.8 预装)
#   - 或 Ubuntu 22.04 + CUDA 
#   - 公网 IP（无需端口映射）
#
# 使用方法:
#   1. 在魔力方舟控制台租用 RTX 4090 服务器
#   2. SSH 连入服务器
#   3. git clone 本仓库
#   4. bash scripts/deploy_molifangzhou.sh
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

# 环境变量: SKIP_INSTALL=1 跳过第3步 RoboDojo 完整安装（用于并行 demo 模式）
SKIP_INSTALL="${SKIP_INSTALL:-0}"

# 绕过 PEP 668（部分脚本内部直接调用系统 pip）
export PIP_BREAK_SYSTEM_PACKAGES=1

echo "============================================================"
echo "  GOAI 2026 · 魔力方舟 GPU 服务器部署"
echo "============================================================"
echo "  Repo root: ${REPO_ROOT}"
echo ""

# ---------- 检测包管理器 ----------
PKG_MGR=""
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt-get"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
elif command -v apk &>/dev/null; then
    PKG_MGR="apk"
else
    echo "  WARNING: 未检测到 apt-get/yum/apk，需手动安装系统依赖"
fi

install_sys_pkg() {
    local pkg="$1"
    if [ -z "${PKG_MGR}" ]; then
        echo "    跳过 ${pkg}（无包管理器）"
        return 0
    fi
    case "${PKG_MGR}" in
        apt-get) sudo apt-get install -y -qq "${pkg}" 2>/dev/null || true ;;
        yum)     sudo yum install -y -q "${pkg}" 2>/dev/null || true ;;
        apk)     sudo apk add --quiet "${pkg}" 2>/dev/null || true ;;
    esac
}

# ---------- 0. 环境检查 ----------
echo "[0/7] 环境检查..."

# GPU 检查
if command -v nvidia-smi &>/dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "Unknown")
    echo "  GPU: ${GPU_INFO}"
else
    echo "  ERROR: nvidia-smi 不可用，请确认 GPU 驱动已安装"
    exit 1
fi

# CUDA 检查
CUDA_VER="unknown"
if command -v nvcc &>/dev/null; then
    CUDA_VER=$(nvcc --version | grep -oP 'release \K[\d.]+' 2>/dev/null || echo "unknown")
elif [ -n "${CUDA_VERSION:-}" ]; then
    CUDA_VER="${CUDA_VERSION}"
elif [ -d "/usr/local/cuda" ]; then
    CUDA_VER=$(cat /usr/local/cuda/version.json 2>/dev/null | grep -oP '"version"\s*:\s*"\K[\d.]+' || echo "unknown")
fi
echo "  CUDA: ${CUDA_VER}"

# Python 检查
PYTHON_VER=$(python --version 2>&1 | grep -oP '\K[\d.]+')
echo "  Python: ${PYTHON_VER}"

# PyTorch 检查（PyTorch 镜像预装）
TORCH_VER="not installed"
if python -c "import torch" 2>/dev/null; then
    TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
    echo "  PyTorch: ${TORCH_VER}"
else
    echo "  PyTorch: not installed (RoboDojo 安装时会装)"
fi

# conda 检查
CONDA_AVAILABLE=false
if command -v conda &>/dev/null; then
    CONDA_VER=$(conda --version 2>/dev/null || echo "Unknown")
    echo "  conda: ${CONDA_VER}"
    CONDA_AVAILABLE=true
else
    # 检查是否已安装 miniforge（之前装过但当前 shell 未激活）
    if [ -f "${HOME}/miniforge3/bin/conda" ]; then
        echo "  conda: miniforge3 已安装，激活中..."
        eval "$("${HOME}/miniforge3/bin/conda" shell.bash hook)"
        CONDA_AVAILABLE=true
    else
        echo "  conda: not available，正在安装 miniforge..."
        # 用清华镜像下载（国内服务器可能连不上 GitHub）
        wget -q https://mirrors.tuna.tsinghua.edu.cn/github-release/conda-forge/miniforge/LatestRelease/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh 2>/dev/null || \
        wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh
        bash /tmp/miniforge.sh -b -p "${HOME}/miniforge3"
        rm -f /tmp/miniforge.sh
        eval "$("${HOME}/miniforge3/bin/conda" shell.bash hook)"
        conda init bash 2>/dev/null || true
        CONDA_AVAILABLE=true
        echo "  miniforge installed."
    fi
fi

echo ""

# ---------- 1. 系统依赖 ----------
echo "[1/7] 安装系统依赖..."
install_sys_pkg "libvulkan1"
install_sys_pkg "mesa-vulkan-drivers"
install_sys_pkg "vulkan-tools"
install_sys_pkg "git-lfs"
install_sys_pkg "ffmpeg"

# 手动安装 git-lfs（部分镜像无包）
if ! command -v git-lfs &>/dev/null; then
    echo "  包管理器未装到 git-lfs，尝试手动安装..."
    wget -q https://github.com/git-lfs/git-lfs/releases/download/v3.5.1/git-lfs-linux-amd64-v3.5.1.tar.gz -O /tmp/glf.tgz
    tar -xzf /tmp/glf.tgz -C /tmp
    /tmp/git-lfs-3.5.1/install.sh 2>/dev/null || cp /tmp/git-lfs-3.5.1/git-lfs /usr/local/bin/
    rm -rf /tmp/glf.tgz /tmp/git-lfs-3.5.1
fi
git lfs install 2>/dev/null || true
echo "  done."
echo ""

# ---------- 2. 克隆 RoboDojo ----------
ROBODOJO_DIR="${REPO_ROOT}/RoboDojo"
echo "[2/7] 克隆 RoboDojo (含 XPolicyLab 子模块)..."
if [ ! -d "${ROBODOJO_DIR}" ]; then
    # GitHub 在国内服务器可能连不上，依次尝试多个镜像
    ROBODOJO_MIRRORS=(
        "https://ghproxy.com/https://github.com/RoboDojo-Benchmark/RoboDojo.git"
        "https://mirror.ghproxy.com/https://github.com/RoboDojo-Benchmark/RoboDojo.git"
        "https://github.com/RoboDojo-Benchmark/RoboDojo.git"
    )
    for url in "${ROBODOJO_MIRRORS[@]}"; do
        echo "  尝试: ${url}"
        if git clone --recurse-submodules "${url}" "${ROBODOJO_DIR}" 2>&1; then
            echo "  RoboDojo cloned from ${url}"
            break
        else
            echo "  失败，尝试下一个镜像..."
            rm -rf "${ROBODOJO_DIR}" 2>/dev/null || true
        fi
    done
    if [ ! -d "${ROBODOJO_DIR}" ]; then
        echo "  ERROR: 所有镜像都失败，请手动配置代理或使用以下命令："
        echo "    git config --global http.proxy http://your_proxy:port"
        echo "    或手动下载后上传到服务器 ${ROBODOJO_DIR}"
        exit 1
    fi
else
    if [ -d "${ROBODOJO_DIR}/.git" ]; then
        cd "${ROBODOJO_DIR}"
        git submodule update --init --recursive
        echo "  RoboDojo already exists (git), submodules updated."
    else
        echo "  RoboDojo already exists (non-git, 手动上传), 跳过 submodule update."
        # 验证 XPolicyLab 是否存在
        if [ ! -d "${ROBODOJO_DIR}/XPolicyLab" ]; then
            echo "  WARNING: XPolicyLab 目录不存在，请确认子模块已手动放入"
        else
            echo "  XPolicyLab 目录存在: OK"
        fi
    fi
fi
echo ""

# ---------- 3. 安装 RoboDojo ----------
echo "[3/7] 安装 RoboDojo (Isaac Sim 5.1 + Isaac Lab + CuRobo)..."
cd "${ROBODOJO_DIR}"

CONDA_BASE=$(conda info --base 2>/dev/null || echo "${HOME}/miniforge3")
ROBODOJO_ENV="${CONDA_BASE}/envs/RoboDojo"

if [ "${SKIP_INSTALL}" = "1" ]; then
    echo "  SKIP_INSTALL=1, 跳过 RoboDojo 安装（稍后在 tmux 中单独运行）。"
elif [ ! -d "${ROBODOJO_ENV}" ]; then
    echo "  创建 RoboDojo conda 环境（Python 3.10）..."
    echo "  这一步耗时较长（30-60 分钟），请耐心等待..."
    # RoboDojo 的 install.sh 会自动创建 conda 环境并安装 Isaac Sim
    bash scripts/install.sh -i
else
    echo "  RoboDojo conda 环境已存在，跳过安装。"
fi
echo ""

# ---------- 4. 下载 GOAI 专用资源 ----------
echo "[4/7] 下载 GOAI-2026 资源 (ModelScope 国内加速)..."
cd "${REPO_ROOT}"
USE_MIRROR=modelscope bash "${SCRIPT_DIR}/download_assets.sh"
echo ""

# ---------- 5. 更新本体路径 ----------
echo "[5/7] 更新本体路径..."
cd "${ROBODOJO_DIR}"
if [ -d "${ROBODOJO_ENV}" ]; then
    conda run -n RoboDojo python utils/update_embodiment_config_path.py
else
    echo "  RoboDojo conda 环境不存在，跳过本体路径更新（demo 模式不需要）。"
fi
echo ""

# ---------- 6. 安装 Policy Adapter ----------
echo "[6/7] 安装 Policy Adapter..."
cd "${REPO_ROOT}"

# 检测 RoboDojo conda 环境是否存在
if [ -d "${ROBODOJO_ENV}" ]; then
    echo "  使用 conda 环境: RoboDojo"
    conda run -n RoboDojo pip install -e .
    POLICY_PYTHON="conda run -n RoboDojo python"
else
    echo "  RoboDojo conda 环境不存在，使用 venv (demo 模式)..."
    VENV_DIR="${REPO_ROOT}/.venv"
    if [ ! -d "${VENV_DIR}" ]; then
        python3 -m venv "${VENV_DIR}"
    fi
    "${VENV_DIR}/bin/pip" install --upgrade pip -q
    "${VENV_DIR}/bin/pip" install -e .
    POLICY_PYTHON="${VENV_DIR}/bin/python"
fi
echo ""

# ---------- 7. 验证 ----------
echo "[7/7] 环境验证..."
cd "${REPO_ROOT}"
${POLICY_PYTHON} scripts/self_check.py || true
echo ""

# ---------- 完成 ----------
echo "============================================================"
echo "  部署完成！"
echo "============================================================"
echo ""
echo "  环境信息："
echo "    GPU:         ${GPU_INFO}"
echo "    CUDA:        ${CUDA_VER}"
echo "    Python:      ${PYTHON_VER} (base) → 3.10 (RoboDojo env)"
echo "    PyTorch:     ${TORCH_VER}"
echo "    conda 环境:  conda activate RoboDojo"
echo "    仓库路径:    ${REPO_ROOT}"
echo "    RoboDojo:    ${ROBODOJO_DIR}"
echo ""
echo "  下一步："
echo "    1. 冒烟测试:  bash scripts/smoke_test.sh"
echo "    2. 启动服务:  bash scripts/start_policy_server.sh"
echo ""
echo "  公网 Policy Server 地址（提交时填写）："
echo "    协议: wss"
echo "    主机: <服务器公网 IP>"
echo "    端口: 9999"
echo ""
echo "  获取公网 IP: curl -s ifconfig.me"
echo "============================================================"
