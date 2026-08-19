"""
Deploy Bridge
=============

连接 RoboDojo 环境观测和 Policy Server 推理。
由 XPolicyLab 的 eval 流程调用，不需要手动运行。
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def run_eval(
    bench_name: str,
    task_name: str,
    ckpt_name: str,
    env_cfg_type: str,
    action_type: str,
    seed: int,
    policy_gpu_id: int,
    env_gpu_id: int,
    policy_env: str,
    eval_env: str,
) -> None:
    """评测入口：由 eval.sh 调用。

    此函数由 XPolicyLab 的 eval 流程驱动，不需要手动调用。
    它负责启动 Policy Server 和环境客户端。
    """
    logger.info(
        f"run_eval | bench={bench_name} task={task_name} ckpt={ckpt_name} "
        f"env_cfg={env_cfg_type} action={action_type} seed={seed}"
    )
    # XPolicyLab 的 eval.sh 已经处理了 server/client 启动
    # 此文件仅作为 Python 入口占位
