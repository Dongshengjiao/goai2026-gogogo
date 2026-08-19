#!/usr/bin/env bash
# Policy Server 启动脚本（策略端）
# 用法:
#   bash setup_eval_policy_server.sh <bench_name> <task_name> <ckpt_name> \
#       <env_cfg_type> <action_type> <seed> <policy_gpu_id> \
#       <policy_env> <port> <bind_host>
#
# 分机部署时绑定 0.0.0.0，客户端用公网 IP 连接。
set -euo pipefail

BENCH_NAME="${1:-RoboDojo}"
TASK_NAME="${2:-stack_bowls}"
CKPT_NAME="${3:-demo}"
ENV_CFG_TYPE="${4:-arx_x5}"
ACTION_TYPE="${5:-ee}"
SEED="${6:-0}"
POLICY_GPU_ID="${7:-0}"
POLICY_ENV="${8:-goai2026_policy}"
PORT="${9:-9999}"
BIND_HOST="${10:-0.0.0.0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "=== Starting Policy Server ==="
echo "  bind:   ${BIND_HOST}:${PORT}"
echo "  ckpt:   ${CKPT_NAME}"
echo "  action: ${ACTION_TYPE}"
echo "  gpu:    ${POLICY_GPU_ID}"

export CUDA_VISIBLE_DEVICES="${POLICY_GPU_ID}"
export ACTION_TYPE="${ACTION_TYPE}"
export CKPT_NAME="${CKPT_NAME}"

# 使用 XPolicyLab 的 policy server 框架
# 如果 XPolicyLab 存在，使用其 server 入口
XPOLICYLAB_ROOT="${XPOLICYLAB_ROOT:-${REPO_ROOT}/RoboDojo/XPolicyLab}"

if [ -d "${XPOLICYLAB_ROOT}" ]; then
    cd "${XPOLICYLAB_ROOT}"
    python -m xpolicylab.server \
        --policy-dir "${SCRIPT_DIR}" \
        --ckpt "${CKPT_NAME}" \
        --port "${PORT}" \
        --host "${BIND_HOST}" \
        --action-type "${ACTION_TYPE}"
else
    # 独立模式：直接启动 websockets server
    echo "XPolicyLab not found, starting standalone server..."
    cd "${REPO_ROOT}"
    python -c "
import sys; sys.path.insert(0, '.')
from policy_adapter.model import Model
import yaml, websockets, asyncio, msgpack, numpy as np

with open('${SCRIPT_DIR}/deploy.yml') as f:
    cfg = yaml.safe_load(f)

model = Model(cfg)

async def handle(ws):
    print(f'Client connected: {ws.remote_address}')
    while True:
        data = await ws.recv()
        req = msgpack.unpackb(data, raw=False)
        cmd = req.get('cmd', '')
        req_id = req.get('request_id', '')
        if cmd == 'update_obs':
            model.update_obs(req['obs'])
            resp = {'request_id': req_id, 'status': 'ok'}
        elif cmd == 'get_action':
            actions = model.get_action()
            resp = {'request_id': req_id, 'actions': actions}
        elif cmd == 'reset':
            model.reset()
            resp = {'request_id': req_id, 'status': 'ok'}
        else:
            resp = {'request_id': req_id, 'error': f'unknown cmd: {cmd}'}
        await ws.send(msgpack.packb(resp, default=lambda o: o.tolist() if isinstance(o, np.ndarray) else o))

async def main():
    print(f'Policy server listening on ${BIND_HOST}:${PORT}')
    async with websockets.serve(handle, '${BIND_HOST}', int('${PORT}')):
        await asyncio.Future()  # run forever

asyncio.run(main())
"
fi
