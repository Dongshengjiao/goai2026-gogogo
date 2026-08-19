# GOAI 2026 · 具身未来赛道 · RoboDojo 参赛项目

基于 **RoboDojo** 基准 + **XPolicyLab** 策略框架，参加 GOAI 世界人工智能开源大赛「具身未来」赛道。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                   官方评测平台 (X-Eval)                    │
│          RoboDojo + Isaac Sim 5.1 仿真环境               │
│              12 任务 × 2 配置 = 24 评测                   │
└────────────────  WebSocket  ────────────────────────────┘
                           │
                           │ obs → action
                           │
┌──────────────────────────┴──────────────────────────────┐
│                  本项目 Policy Server                    │
│                                                          │
│  ┌─────────────┐   ┌──────────────┐   ┌─────────────┐  │
│  │ deploy.yml  │──│ Policy Server │──│  model.py   │  │
│  │ (配置)      │   │ (WebSocket)  │   │ (VLA 推理)  │  │
│  └─────────────┘   └──────────────┘   └─────────────┘  │
│                                                          │
│  缺 torch 时降级为 demo_policy（返回零动作）              │
│  冒烟测试验证链路可通                                    │
└──────────────────────────────────────────────────────────┘
```

## 项目结构

```
goai2026-robodojo/
├── policy_adapter/          # XPolicyLab 标准策略适配器
│   ├── model.py             # Model 契约接口（核心）
│   ├── deploy.py            # 评测桥接
│   ├── deploy.yml           # 运行时配置
│   ├── eval.sh              # 同机评测脚本
│   ├── install.sh           # 策略环境安装
│   ├── setup_eval_policy_server.sh   # Policy Server 启动
│   └── setup_eval_env_client.sh      # 仿真客户端启动
├── configs/
│   ├── tasks.yaml           # 12 个 RoboDojo 任务定义
│   ├── policy.yaml          # Policy Server 部署配置
│   └── deploy.yml           # deploy.yml 模板
├── scripts/
│   ├── install_robodojo.sh  # 一键安装 RoboDojo + Isaac Sim
│   ├── download_assets.sh   # 下载 GOAI-2026 资产和数据
│   ├── smoke_test.sh        # 官方冒烟测试（24 配置）
│   ├── start_policy_server.sh  # 启动公网 Policy Server
│   └── self_check.py        # 环境自检
├── pyproject.toml
├── requirements.txt
└── README.md
```

## 快速开始

### 1. 环境要求

- **OS**: Ubuntu 22.04 (Linux x64)
- **GPU**: NVIDIA GPU, VRAM >= 16GB
- **NVIDIA Driver**: 570 或 580
- **CUDA**: 12.8
- **RAM**: 32 GB+

### 2. 安装

```bash
# 克隆本仓库
git clone <your-repo-url> goai2026-robodojo
cd goai2026-robodojo

# 安装本项目的 Python 依赖
pip install -e .

# 一键安装 RoboDojo + Isaac Sim 5.1 + XPolicyLab
bash scripts/install_robodojo.sh
```

### 3. 冒烟测试

```bash
# 环境自检
python scripts/self_check.py

# 官方冒烟测试（24 配置 × 1 episode）
bash scripts/smoke_test.sh
```

冒烟测试 `success_rate=0.0` 是正常的（demo 模式返回零动作），它只验证端到端链路。

### 4. 接入真实模型

编辑 [policy_adapter/model.py](policy_adapter/model.py) 的 `_load_model()` 和 `get_action()`：

```python
# _load_model() 中：
from transformers import AutoModelForVision2Seq, AutoProcessor
self._model = AutoModelForVision2Seq.from_pretrained(
    str(self.ckpt_path), torch_dtype=torch.bfloat16
).to(self.device)
self._processor = AutoProcessor.from_pretrained(str(self.ckpt_path))

# get_action() 中：
obs = self._obs_history[-1]
images = [v["color"] for v in obs.get("vision", {}).values()]
inputs = self._processor(images=images, text=obs.get("instruction", ""))
outputs = self._model.generate(**inputs)
actions = self._decode_actions(outputs)
return actions
```

也可以直接使用 XPolicyLab 已集成的 41 个策略（如 ACT、π0、MolmoAct2 等），
将 `policy_adapter/` 替换为对应策略目录即可。

### 5. 提交评测

```bash
# 启动公网 Policy Server
bash scripts/start_policy_server.sh

# 在另一终端验证服务可达
curl -i http://<YOUR_PUBLIC_IP>:9999
```

然后在 [https://xsparkai.com/goai-2026/apply](https://xsparkai.com/goai-2026/apply) 填写：
- 队伍名称、联系人、手机号、邮箱
- Policy Server: `wss://<YOUR_PUBLIC_IP>:9999`
- 策略名: `goai2026_policy`
- 动作类型: `ee`（或 `joint`，须与本地一致）

## 评测任务（12 项）

| 任务 | 说明 | 评分 |
|---|---|---|
| stack_bowls | 三个碗叠放 | 0 / 15 / 100 |
| push_T | 推 T 形物体到目标位 | 0 / 15 / 100 |
| pack_objects_into_box | 物体装箱 | 0 / 15 / 100 |
| fold_clothes | 折衣服 | 0 / 15 / 100 |
| hang_mugs | 挂杯子 | 0 / 15 / 100 |
| sweep_blocks | 扫积木 | 0 / 15 / 100 |
| pour_liquid_into_cup | 倒液体 | 0 / 15 / 100 |
| make_toast | 做烤面包 | 0 / 15 / 100 |
| arrange_largest_number | 排列最大数字 | 0 / 15 / 100 |
| sort_nesting_dolls_by_size | 套娃按大小排序 | 0 / 15 / 100 |
| store_laptop_and_headphones | 收纳笔记本和耳机 | 0 / 15 / 100 |
| stack_blocks | 叠积木 | 0 / 15 / 100 |

每个任务有标准 + `_random` 两个配置，共 24 个评测。初赛最多提交 3 次，取最高分。

## 关键日期

| 事项 | 时间 (AOE) |
|---|---|
| 报名开始 | Jul. 16th |
| 初赛 | Jul. 16th – Aug. 20th |
| 初赛评审 | Aug. 21st – Aug. 23rd |
| 决赛 | Sep. 22nd – Sep. 23rd |

## 参赛全流程

1. **GOAI 官网注册**: [goaihz.com](https://www.goaihz.com/) → 登录/注册 → 立即报名
2. **本站提交评测申请**: [xsparkai.com/goai-2026/apply](https://xsparkai.com/goai-2026/apply) → 填写 Policy Server 信息
3. **收到评测结果邮件**: 官方完成评测后发送结果
4. **GOAI 官网提交作品**: 个人中心 → 我的报名 → 提交作品（代码仓库 + 评测结果邮件）

## License

- 代码: Apache License 2.0
- 文档: CC BY 4.0
