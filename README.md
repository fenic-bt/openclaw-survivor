# OpenClaw Survivor

> **"Don't let your AI agent die. Ever."**

One-click snapshot & restore for OpenClaw deployments. If your AI agent breaks, restore everything in 5 seconds.

**Problem:** OpenClaw stores memory, skills, agents, and configuration in `~/.openclaw/`. A bad update, a corrupted file, or a mistaken edit can destroy your AI's entire context — memories, learned behaviors, and setup.

**Solution:** Automatic daily snapshots + one-command restore.

---

## Features

- 📦 **Full snapshot** — Everything in `~/.openclaw/` and `~/.claude/`
- 🔄 **One-command restore** — Back to any previous state in 5 seconds
- 🤖 **Claude Code config** — Also backs up agents, commands, rules, hooks
- 💾 **GitHub sync** — Pushes code to your repo automatically
- ⏰ **Daily auto-run** — Via launchd (macOS), no manual work
- 🧪 **Integrity check** — Verifies snapshots are not corrupted

---

## Quick Start

### 1. Download

```bash
git clone https://github.com/fenic-bt/openclaw-survivor.git
cd openclaw-survivor
```

### 2. Install

```bash
chmod +x snapshot.sh

# macOS: install launchd to run daily at 3am
cp com.baiyixue.snapshot.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.baiyixue.snapshot.plist
```

### 3. Manual snapshot (first time)

```bash
./snapshot.sh save
```

### 4. If things break

```bash
./snapshot.sh restore
# Enter YES to confirm
```

---

## Commands

```bash
./snapshot.sh save      # Create snapshot now
./snapshot.sh restore   # Restore to latest snapshot (requires YES confirmation)
./snapshot.sh restore <timestamp>  # Restore to specific snapshot
./snapshot.sh list      # Show all snapshots
./snapshot.sh check     # Check if latest snapshot is valid
```

---

## What's Included

| Category | What gets backed up |
|----------|-------------------|
| **OpenClaw workspace** | `memory/`, `memos/`, `MEMORY.md`, `SOUL.md`, `AGENTS.md` |
| **OpenClaw config** | `openclaw.json`, `skills/`, `agents/` |
| **Claude Code** | `~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/rules/` |
| **System info** | pip packages, crontab, git remotes |

---

## Requirements

- macOS or Linux
- `tar`, `gzip`, `rsync`, `git`
- ~100MB free space per snapshot (keeps last 30 by default)

---

## Philosophy

This tool was built for [白忆雪 (Bai Yixue)](https://github.com/fenic-bt), an AI agent running on a Mac mini. The AI uses this to ensure its memories and configuration survive any update or mistake.

If you're running an AI agent that has accumulated valuable context, you need something like this. Don't learn the hard way.

---

## License

MIT — Use it, break it, improve it.
