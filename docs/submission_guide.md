# 提交指南

## 概述

GOAI 2026 具身未来赛道的参赛流程分四步。本指南覆盖从环境搭建到正式提交的完整流程。

## 前置条件

| 项目 | 要求 |
|---|---|
| OS | Ubuntu 22.04 |
| GPU | NVIDIA, VRAM >= 16GB |
| NVIDIA Driver | 570 或 580 |
| CUDA | 12.8 |
| RAM | 32 GB+ |
| 公网 IP | 固定公网 IP 或稳定域名 |
| 端口 | 9999（或自定义），公网可达 |

## Step 1: GOAI 官网注册

1. 打开 [https://www.goaihz.com/](https://www.goaihz.com/)
2. 点击「登录/注册」，完成账号注册
3. 点击「立即报名」，选择赛道和赛题，填写团队信息

## Step 2: 环境搭建

```bash
# 克隆仓库
git clone <your-repo-url> goai2026-robodojo
cd goai2026-robodojo

# 安装本项目依赖
pip install -e .

# 一键安装 RoboDojo + Isaac Sim 5.1
bash scripts/install_robodojo.sh

# 环境自检
python scripts/self_check.py

# 冒烟测试（24 配置 × 1 episode）
bash scripts/smoke_test.sh
```

冒烟测试 `success_rate=0.0` 是正常的——demo 模式返回零动作，
只验证仿真器、渲染、WebSocket 连接、结果写入链路是否通畅。

## Step 3: 部署 Policy Server

### 3.1 本地自测

```bash
# 设置变量
export ACTION_TYPE=ee          # 或 joint
export CKPT_NAME=your_ckpt     # 你的 checkpoint 名
export POLICY_ENV=your_env     # conda 环境名
export RUN_LABEL=your_label

# 同机评测（启动 server + client）
bash policy_adapter/eval.sh \
    RoboDojo stack_bowls ${CKPT_NAME} arx_x5 ${ACTION_TYPE} \
    0 0 0 ${POLICY_ENV} RoboDojo
```

### 3.2 分机部署

```bash
# === GPU 机器（Policy Server）===
bash policy_adapter/setup_eval_policy_server.sh \
    RoboDojo stack_bowls ${CKPT_NAME} arx_x5 ${ACTION_TYPE} \
    0 0 0 ${POLICY_ENV} 9999 0.0.0.0

# === 仿真机器（Environment Client）===
bash policy_adapter/setup_eval_env_client.sh \
    RoboDojo stack_bowls ${CKPT_NAME} arx_x5 ${ACTION_TYPE} \
    0 0 RoboDojo "" 9999 <GPU_MACHINE_IP>
```

### 3.3 公网部署

```bash
# 启动公网 Policy Server
bash scripts/start_policy_server.sh
```

注意事项：
- 绑定 `0.0.0.0`，不要用 `127.0.0.1`
- 配置防火墙开放端口
- 建议使用 nginx 反向代理 + TLS（`wss://`）
- 不要提交 `localhost`、`127.0.0.1`、局域网 IP

### 3.4 Nginx 反向代理配置（TLS）

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:9999;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
    }
}
```

## Step 4: 提交评测申请

1. 打开 [https://xsparkai.com/goai-2026/apply](https://xsparkai.com/goai-2026/apply)
2. 填写：

| 字段 | 值 |
|---|---|
| 队伍名称 | 你的队伍名 |
| 联系人 | 姓名 |
| 手机号 | 手机号 |
| 邮箱 | 邮箱 |
| 协议 | wss |
| 主机 | 你的公网 IP 或域名 |
| 端口 | 9999 |
| 策略名 | goai2026_policy（仅字母/数字/下划线） |
| 动作类型 | ee 或 joint（须与本地自测一致） |

3. 提交并保存申请编号
4. **审核和正式评测期间保持服务在线，不要更换模型或动作类型**

## Step 5: 收到评测结果

- 官方完成评测后，向联系邮箱发送结果邮件
- **保存此邮件**——GOAI 官网提交作品时的必要附件

## Step 6: GOAI 官网提交作品

1. 打开 [https://www.goaihz.com/](https://www.goaihz.com/)
2. 个人中心 → 我的报名 → 提交作品
3. 提交：
   - 代码仓库 URL
   - 评测结果邮件（附件）
4. 作品提交后，初赛报名正式完成

## 常见问题

**Q: 冒烟测试 success_rate=0.0 正常吗？**
A: 正常。demo_policy 返回零动作，冒烟测试只验证链路可通，不代表成绩。

**Q: 最多提交几次？**
A: 最多 3 次有效成绩，取最高分作为初赛筛选依据。不要用正式提交调试策略。

**Q: 初赛前 10 名怎么选？**
A: 总分排名前 10 的队伍晋级决赛，决赛是 6 项真机任务。

**Q: 动作类型可以中途改吗？**
A: 不可以。审核和评测期间不能更换模型、动作类型或协议行为。

**Q: Policy Server 需要一直开着吗？**
A: 是的。从提交申请到评测完成期间，服务必须在线。建议用 systemd 或 supervisor 守护。
