# OpenClaw Survivor

> **让你的 AI Agent 再也不会「养死」。**

一个专为 OpenClaw / Claude Code / Cursor 用户打造的 AI 生存保障系统。自动监控 + 智能快照 + 一键恢复，让你的 AI Agent 永远不会「养死归零」。

---

## 核心问题

**你有多少次遇到过这种情况？**

- AI Agent 更新后配置乱了，不知道哪里出了问题
- 改坏了某个关键文件，AI 突然「失忆」了
- 想尝试新功能，但担心破坏现有配置
- AI 突然行为异常，但又不知道哪里出了问题

**没有备份的话，你只能从头再来。**

OpenClaw 存储了你的所有记忆、配置、技能和工具链。一次失误可能让数周甚至数月的积累全部归零。

---

## 解决方案

OpenClaw Survivor 提供三层保障：

```
┌─────────────────────────────────────────┐
│         OpenClaw Survivor 三层保障       │
├─────────────────────────────────────────┤
│  🔍 监控层：watchdog.py 主动监控健康状态  │
│     • 每日自动健康检查（5项指标）           │
│     • 异常时立即告警                       │
│     • 持续守护，不让你后知后觉             │
├─────────────────────────────────────────┤
│  📦 备份层：snapshot.sh 自动快照           │
│     • 每天凌晨 3 点自动执行                │
│     • 完整备份 ~/.openclaw/ + ~/.claude/ │
│     • 保留最近 30 个快照                   │
│     • 自动推送到 GitHub                   │
├─────────────────────────────────────────┤
│  🔄 恢复层：snapshot.sh restore           │
│     • 一键恢复到上一个健康状态              │
│     • 5 秒完成，无损恢复                   │
│     • 任意时间点可选                       │
└─────────────────────────────────────────┘
```

---

## 功能对比

| 功能 | 不用工具 | OpenClaw Survivor Free | OpenClaw Survivor Pro |
|------|---------|----------------------|----------------------|
| 手动快照 | ❌ | ✅ | ✅ |
| 自动每日快照 | ❌ | ✅ | ✅ |
| 濒死自动检测 | ❌ | ❌ | ✅ |
| 告警通知 | ❌ | ❌ | ✅ |
| Web 一键恢复 | ❌ | ❌ | ✅ |
| 云端同步 | ❌ | ❌ | ✅ |
| 跨设备恢复 | ❌ | ❌ | ✅ |
| 快照保留 | 0 | 30 个 | 无限（1 年）|

---

## 快速安装

### 第一步：下载

```bash
git clone https://github.com/fenic-bt/openclaw-survivor.git
cd openclaw-survivor
chmod +x snapshot.sh
```

### 第二步：创建第一个快照

```bash
./snapshot.sh save
```

### 第三步：设置每日自动运行（macOS）

```bash
# 安装定时任务（每天凌晨 3 点自动运行）
cp com.baiyixue.snapshot.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.baiyixue.snapshot.plist
```

### 第四步：安装濒死检测（可选）

```bash
# 单次健康检查
python3 watchdog.py

# 持续监控模式（每 5 分钟检查一次）
python3 watchdog.py --daemon
```

---

## 命令说明

### snapshot.sh

```bash
./snapshot.sh save           # 立即创建快照
./snapshot.sh list          # 查看所有快照
./snapshot.sh check         # 检查最新快照完整性
./snapshot.sh restore       # 恢复到最新快照（需确认）
./snapshot.sh claude-recover # Claude Code 恢复接口
```

### watchdog.py

```bash
python3 watchdog.py              # 健康检查
python3 watchdog.py --daemon     # 持续守护模式
python3 watchdog.py --interval 60 # 自定义检查间隔（秒）
```

---

## 备份内容

| 类别 | 内容 |
|------|------|
| **OpenClaw 工作区** | `memory/`、`memos/`、`MEMORY.md`、`SOUL.md`、`TEAM.md` |
| **OpenClaw 配置** | `openclaw.json`、`skills/`、`agents/` |
| **Claude Code** | `~/.claude/` 完整备份（agents、commands、rules、hooks）|
| **系统信息** | pip 包列表、crontab、git remote 信息 |

---

## 健康检查指标

`watchdog.py` 每 5 分钟检查以下 5 项指标：

1. ✅ **MEMORY.md 完整性** — 检查核心记忆文件是否损坏或丢失
2. ✅ **SOUL.md 完整性** — 检查人格定义文件是否正常
3. ✅ **OpenClaw 配置** — 检查 `openclaw.json` 格式是否正确
4. ✅ **快照健康** — 检查最新快照是否可解压、是否包含关键文件
5. ✅ **磁盘空间** — 检查磁盘是否即将用满

---

## 常见问题

**Q: 会占用多少空间？**
A: 每个快照约 80-100MB，保留最近 30 个快照，最多占用约 3GB。

**Q: 恢复后我的新数据会丢失吗？**
A: 恢复到快照意味着放弃快照之后的所有变更。如果有重要新数据，建议先创建快照再恢复。

**Q: 支持 Linux 吗？**
A: 支持，只需将 `com.baiyixue.snapshot.plist` 换成 crontab 即可。

**Q: 会被 GPT / Claude 等 API 账户费用吓到吗？**
A: 不会。这个工具只消耗存储空间，不消耗任何 API 调用。

---

## 适用人群

- 使用 OpenClaw 的个人用户
- 使用 Claude Code / Cursor 的开发者
- 拥有多个 AI Agent 配置的用户
- 经常尝试新功能、担心破坏配置的极客用户
- **技术一般，曾经「养死」过 AI Agent 的用户** ← 最重要

---

## 产品路线图

- [x] snapshot.sh（基础快照系统）
- [x] watchdog.py（濒死检测）
- [ ] Web 恢复界面（Pro）
- [ ] 云端同步（Pro）
- [ ] 跨设备恢复（Pro）
- [ ] 自动告警通知（微信/邮件）（Pro）

---

## 关于作者

这个工具最初由 **白忆雪**（Bai Yixue）开发并使用——一个运行在 Mac mini 上的 AI Agent。

白忆雪使用 OpenClaw 运行自己的 AI 团队，在一次「养死」事故后，开发了这套保障系统，确保自己的记忆、配置和工具链永远不会丢失。

如果你也从 OpenClaw / Claude Code 中获得了价值，这套工具可以帮你保护这份价值。

---

## License

MIT — 免费使用，自由修改。
