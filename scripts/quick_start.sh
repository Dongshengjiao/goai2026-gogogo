#!/usr/bin/env bash
# ============================================================
# 快速启动 Policy Server（demo 模式）
# 用途：明天截止，先提交评测走通流程
# 不需要 Isaac Sim、Assets、hdf5 数据
# 只需要 Python + websockets + msgpack
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
PORT="${PORT:-9999}"
BIND_HOST="${BIND_HOST:-0.0.0.0}"

echo "============================================================"
echo "  GOAI 2026 · 快速启动 Policy Server (demo 模式)"
echo "============================================================"

# 1. 选 Python 环境
PYTHON_BIN=""
if command -v conda &>/dev/null; then
    if conda env list 2>/dev/null | grep -q "RoboDojo"; then
        echo "[1/3] 使用 conda 环境: RoboDojo"
        eval "$(conda shell.bash hook)"
        conda activate RoboDojo
        PYTHON_BIN="python"
    fi
fi

if [ -z "${PYTHON_BIN}" ]; then
    VENV_DIR="${REPO_ROOT}/.venv"
    echo "[1/3] conda 不可用，使用 venv..."
    if [ ! -d "${VENV_DIR}" ]; then
        python3 -m venv "${VENV_DIR}"
    fi
    "${VENV_DIR}/bin/pip" install --upgrade pip -q
    PYTHON_BIN="${VENV_DIR}/bin/python"
fi

# 2. 安装最小依赖
echo "[2/3] 安装最小依赖..."
${PYTHON_BIN} -m pip install --break-system-packages numpy pyyaml websockets msgpack 2>/dev/null || \
    ${PYTHON_BIN} -m pip install numpy pyyaml websockets msgpack 2>/dev/null || true
echo "  依赖检查:"
${PYTHON_BIN} -c "import numpy, yaml, websockets, msgpack; print('  numpy, yaml, websockets, msgpack: OK')"

# 3. 启动 Policy Server
echo "[3/3] 启动 Policy Server..."
echo "  bind: ${BIND_HOST}:${PORT}"
echo ""
echo "  >>> 提交评测时填写 <<<"
echo "  协议: ws"
echo "  主机: $(curl -s ifconfig.me 2>/dev/null || echo '<YOUR_PUBLIC_IP>')"
echo "  端口: ${PORT}"
echo "  策略名: goai2026_policy"
echo "  动作类型: ee"
echo ""
echo "  Ctrl+C 停止"
echo "============================================================"

cd "${REPO_ROOT}"
exec ${PYTHON_BIN} -c "
import sys, os, yaml, json, asyncio, websockets, msgpack, numpy as np
sys.path.insert(0, '.')
from policy_adapter.model import Model

# 加载配置
with open('policy_adapter/deploy.yml') as f:
    cfg = yaml.safe_load(f)

cfg['action_type'] = 'ee'
cfg['chunk_size'] = 10
cfg['device'] = 'cpu'

model = Model(cfg)
print(f'Model ready | mode={\"demo\" if model._model is None else \"real\"} | action_type={model.action_type}')

async def handle(ws):
    print(f'Client connected: {ws.remote_address}')
    try:
        async for data in ws:
            req = msgpack.unpackb(data, raw=False)
            cmd = req.get('cmd', '')
            req_id = req.get('request_id', '')
            if cmd == 'update_obs':
                model.update_obs(req.get('obs', {}))
                resp = {'request_id': req_id, 'status': 'ok'}
            elif cmd == 'get_action':
                actions = model.get_action()
                resp = {'request_id': req_id, 'actions': actions}
            elif cmd == 'reset':
                model.reset()
                resp = {'request_id': req_id, 'status': 'ok'}
            elif cmd == 'init':
                resp = {'request_id': req_id, 'status': 'ok', 'message': 'Policy server ready'}
            else:
                resp = {'request_id': req_id, 'status': 'ok', 'error': f'unknown cmd: {cmd}'}
            await ws.send(msgpack.packb(resp, default=lambda o: o.tolist() if isinstance(o, np.ndarray) else o))
    except websockets.exceptions.ConnectionClosed:
        print(f'Client disconnected')
    except Exception as e:
        print(f'Error: {e}')

async def main():
    print(f'Policy server listening on ${BIND_HOST}:${PORT}')
    async with websockets.serve(handle, '${BIND_HOST}', int('${PORT}'), ping_interval=20, ping_timeout=20):
        await asyncio.Future()

asyncio.run(main())
"
