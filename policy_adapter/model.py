"""
Model Adapter
=============

实现 XPolicyLab 的 Model 契约接口。
RoboDojo 评测客户端通过 WebSocket 发送观测数据，
本适配器调用 VLA 模型生成动作并返回。

当 torch/transformers 不可用时，降级为 demo_policy（返回零动作），
保证冒烟测试端到端链路可通。

XPolicyLab Model 契约:
    __init__(model_cfg)          从 deploy.yml 加载配置和权重
    update_obs(obs)              接收单条观测（含相机图像）
    update_obs_batch(obs_list)   批量接收观测
    get_action()                 返回动作 chunk（list[dict]）
    get_action_batch(env_idx)    批量返回动作
    reset()                      episode 之间清除状态
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Dict, List, Optional

import numpy as np
import yaml

logger = logging.getLogger(__name__)

# 尝试导入 torch（可选，缺失时降级为 demo 模式）
try:
    import torch

    _HAS_TORCH = True
except Exception:
    torch = None  # type: ignore
    _HAS_TORCH = False


class Model:
    """GOAI 2026 策略模型适配器。

    实现了 XPolicyLab 的标准 Model 接口。
    支持两种模式：
    1. 真实模式：加载 VLA 模型权重，进行推理
    2. Demo 模式：返回零动作（用于冒烟测试，验证端到端链路）

    Args:
        model_cfg: 从 deploy.yml 加载的配置字典

    Example:
        >>> model = Model({"ckpt_dir": "checkpoints/", "action_type": "ee"})
        >>> model.update_obs({"vision": {"front": {"color": img}}, "state": {...}})
        >>> actions = model.get_action()
    """

    def __init__(self, model_cfg: Dict[str, Any]) -> None:
        self.cfg = model_cfg
        self.action_type: str = model_cfg.get("action_type", "ee")
        self.chunk_size: int = model_cfg.get("chunk_size", 10)
        self.device: str = model_cfg.get("device", "cuda:0" if _HAS_TORCH else "cpu")
        self.temporal_agg: bool = model_cfg.get("temporal_agg", True)

        # 加载 checkpoint
        ckpt_dir = model_cfg.get("ckpt_dir", "checkpoints/")
        self.ckpt_path = Path(ckpt_dir)
        self._model = None
        self._processor = None

        # 状态
        self._obs_history: List[Dict[str, Any]] = []
        self._action_queue: List[Dict[str, Any]] = []
        self._step_count: int = 0

        if _HAS_TORCH:
            self._load_model()
        else:
            logger.warning(
                "torch not available, running in DEMO mode (zero actions). "
                "Install torch to enable real inference."
            )

        logger.info(
            f"Model initialized | action_type={self.action_type} "
            f"| chunk_size={self.chunk_size} | device={self.device} "
            f"| mode={'real' if self._model else 'demo'}"
        )

    def _load_model(self) -> None:
        """加载 VLA 模型权重。

        从 ckpt_dir 加载模型。当权重文件不存在时降级为 demo 模式。
        接入真实模型时替换此方法。
        """
        ckpt_file = self.ckpt_path / "model.pt"
        if not ckpt_file.exists():
            logger.warning(
                f"Checkpoint not found at {ckpt_file}, running in DEMO mode"
            )
            return

        try:
            logger.info(f"Loading model from {ckpt_file}...")
            # === 接入真实 VLA 模型 ===
            # 示例：加载 HuggingFace VLA 模型
            # from transformers import AutoModelForVision2Seq, AutoProcessor
            # self._model = AutoModelForVision2Seq.from_pretrained(
            #     str(self.ckpt_path), torch_dtype=torch.bfloat16
            # ).to(self.device)
            # self._processor = AutoProcessor.from_pretrained(str(self.ckpt_path))

            # 当前：加载 state_dict 占位
            state = torch.load(ckpt_file, map_location=self.device, weights_only=True)
            logger.info(f"Loaded checkpoint with {len(state)} keys")
            self._model = state  # 占位，接入真实模型时替换
        except Exception as e:
            logger.error(f"Failed to load model: {e}", exc_info=True)
            self._model = None

    def update_obs(self, obs: Dict[str, Any]) -> None:
        """接收一条观测数据，更新模型内部状态。

        XPolicyLab server 在调用前已将相机图像解码为 numpy 数组，
        obs["vision"][<camera>]["color"] 直接是图像 array。

        Args:
            obs: 观测字典，包含：
                - vision: 相机观测 {camera_name: {"color": HxWxC array}}
                - state: 机器人本体状态（关节角/末端位姿等）
                - instruction: 自然语言指令
        """
        self._obs_history.append(obs)
        # 保留最近 N 条观测（滑动窗口）
        max_history = 16
        if len(self._obs_history) > max_history:
            self._obs_history = self._obs_history[-max_history:]

        logger.debug(
            f"update_obs | step={self._step_count} "
            f"| vision_keys={list(obs.get('vision', {}).keys())}"
        )

    def update_obs_batch(self, obs_list: List[Dict[str, Any]]) -> None:
        """批量接收观测（多环境并行评测时调用）。

        Args:
            obs_list: 观测列表，每个元素同 update_obs 的 obs
        """
        for obs in obs_list:
            self.update_obs(obs)

    def get_action(self) -> List[Dict[str, Any]]:
        """生成动作 chunk 并返回。

        返回一个包含 chunk_size 条动作的列表。
        每条动作是一个字典，格式取决于 action_type：
        - ee: {"ee_pose": [x,y,z,qx,qy,qz,qw], "gripper": float}
        - joint: {"joint_pos": [j1,...,j7], "gripper": float}

        Demo 模式返回零动作，确保冒烟测试链路可通。

        Returns:
            动作字典列表
        """
        self._step_count += 1

        if self._model is None:
            # Demo 模式：返回零动作
            return self._zero_action_chunk()

        # === 真实推理 ===
        # 接入真实 VLA 模型时替换此处
        # obs = self._obs_history[-1]
        # images = [v["color"] for v in obs.get("vision", {}).values()]
        # inputs = self._processor(images=images, text=obs.get("instruction", ""))
        # outputs = self._model.generate(**inputs)
        # actions = self._decode_actions(outputs)
        # return actions

        return self._zero_action_chunk()

    def get_action_batch(
        self, env_idx_list: Optional[List[int]] = None
    ) -> List[List[Dict[str, Any]]]:
        """批量返回动作（多环境并行评测时调用）。

        Args:
            env_idx_list: 活跃环境索引列表，None 表示所有环境

        Returns:
            动作 chunk 列表，每个元素同 get_action 的返回值
        """
        if env_idx_list is None:
            return [self.get_action()]
        return [self.get_action() for _ in env_idx_list]

    def reset(self) -> None:
        """清除 episode 之间的状态。

        评测开始新 episode 时调用，重置观测历史和动作队列。
        """
        self._obs_history.clear()
        self._action_queue.clear()
        self._step_count = 0
        logger.debug("Model state reset")

    # ------------------------------------------------------------------
    # 内部工具
    # ------------------------------------------------------------------
    def _zero_action_chunk(self) -> List[Dict[str, Any]]:
        """生成零动作 chunk（demo 模式）。"""
        if self.action_type == "ee":
            # 末端位姿: [x, y, z, qx, qy, qz, qw] + gripper
            action = {
                "ee_pose": [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
                "gripper": 0.0,
            }
        else:
            # 关节角: 7 DoF + gripper
            action = {
                "joint_pos": [0.0] * 7,
                "gripper": 0.0,
            }

        return [action.copy() for _ in range(self.chunk_size)]

    def _decode_actions(self, outputs: Any) -> List[Dict[str, Any]]:
        """将模型原始输出解码为动作格式。

        接入真实模型时实现此方法，将 VLA 输出转换为 RoboDojo 动作格式。
        """
        raise NotImplementedError("Override this when integrating a real model")
