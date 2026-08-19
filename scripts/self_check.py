#!/usr/bin/env python3
"""
Self-Check: 验证项目环境是否就绪
检查依赖、配置、RoboDojo 安装、Policy Adapter 完整性。

用法:
    python scripts/self_check.py
"""

from __future__ import annotations

import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def check(name: str, condition: bool, detail: str = "") -> bool:
    status = "OK" if condition else "FAIL"
    print(f"  [{status}] {name}" + (f" - {detail}" if detail else ""))
    return condition


def main() -> int:
    print("=" * 50)
    print("  GOAI 2026 Self-Check")
    print("=" * 50)
    print()

    all_ok = True

    # 1. Python 依赖
    print("[1] Python Dependencies")
    try:
        import numpy

        all_ok &= check("numpy", True, numpy.__version__)
    except ImportError:
        all_ok &= check("numpy", False, "pip install numpy")

    try:
        import yaml

        all_ok &= check("pyyaml", True, yaml.__version__)
    except ImportError:
        all_ok &= check("pyyaml", False, "pip install pyyaml")

    try:
        import websockets

        all_ok &= check("websockets", True, websockets.__version__)
    except ImportError:
        all_ok &= check("websockets", False, "pip install websockets")

    try:
        import msgpack

        all_ok &= check("msgpack", True)
    except ImportError:
        all_ok &= check("msgpack", False, "pip install msgpack")

    try:
        import torch

        all_ok &= check("torch (optional)", True, torch.__version__)
    except ImportError:
        check("torch (optional)", False, "demo mode (zero actions)")
    print()

    # 2. 配置文件
    print("[2] Config Files")
    all_ok &= check(
        "pyproject.toml",
        (REPO_ROOT / "pyproject.toml").exists(),
    )
    all_ok &= check(
        "requirements.txt",
        (REPO_ROOT / "requirements.txt").exists(),
    )
    all_ok &= check(
        "configs/tasks.yaml",
        (REPO_ROOT / "configs" / "tasks.yaml").exists(),
    )
    all_ok &= check(
        "configs/policy.yaml",
        (REPO_ROOT / "configs" / "policy.yaml").exists(),
    )
    print()

    # 3. Policy Adapter
    print("[3] Policy Adapter")
    adapter_dir = REPO_ROOT / "policy_adapter"
    all_ok &= check("__init__.py", (adapter_dir / "__init__.py").exists())
    all_ok &= check("model.py", (adapter_dir / "model.py").exists())
    all_ok &= check("deploy.py", (adapter_dir / "deploy.py").exists())
    all_ok &= check("deploy.yml", (adapter_dir / "deploy.yml").exists())
    all_ok &= check("eval.sh", (adapter_dir / "eval.sh").exists())
    all_ok &= check("install.sh", (adapter_dir / "install.sh").exists())
    all_ok &= check(
        "setup_eval_policy_server.sh",
        (adapter_dir / "setup_eval_policy_server.sh").exists(),
    )
    all_ok &= check(
        "setup_eval_env_client.sh",
        (adapter_dir / "setup_eval_env_client.sh").exists(),
    )
    print()

    # 4. Model 接口
    print("[4] Model Interface")
    try:
        sys.path.insert(0, str(REPO_ROOT))
        from policy_adapter.model import Model

        model = Model({"action_type": "ee", "chunk_size": 10, "ckpt_dir": "/tmp"})
        model.reset()
        model.update_obs({"vision": {"front": {"color": [[0, 0, 0]]}}, "state": {}})
        actions = model.get_action()
        assert len(actions) == 10, f"Expected 10 actions, got {len(actions)}"
        assert "ee_pose" in actions[0], "Missing ee_pose key"
        all_ok &= check("Model.__init__", True)
        all_ok &= check("Model.update_obs", True)
        all_ok &= check("Model.get_action", True, f"{len(actions)} actions")
        all_ok &= check("Model.reset", True)
    except Exception as e:
        all_ok &= check("Model interface", False, str(e))
    print()

    # 5. RoboDojo
    print("[5] RoboDojo")
    robodojo_dir = REPO_ROOT / "RoboDojo"
    all_ok &= check(
        "RoboDojo cloned",
        (robodojo_dir / "scripts" / "robodojo.sh").exists(),
        "Run scripts/install_robodojo.sh" if not (robodojo_dir / "scripts" / "robodojo.sh").exists() else "",
    )
    all_ok &= check(
        "Assets downloaded",
        (robodojo_dir / "Assets").exists(),
        "Run scripts/download_assets.sh" if not (robodojo_dir / "Assets").exists() else "",
    )
    print()

    # 总结
    print("=" * 50)
    if all_ok:
        print("  All checks passed!")
        print("  Next steps:")
        print("    1. bash scripts/install_robodojo.sh")
        print("    2. bash scripts/smoke_test.sh")
        print("    3. bash scripts/start_policy_server.sh")
        print("    4. Submit at https://xsparkai.com/goai-2026/apply")
    else:
        print("  Some checks failed. Fix the issues above.")
    print("=" * 50)

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
