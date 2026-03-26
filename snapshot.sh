#!/bin/bash
# ================================================================
# 白忆雪生存保障系统 - Snapshot v1.0
# 用途：每日全量快照 + 一键还原
# 使用：./snapshot.sh [save|restore|list|check]
# ================================================================

set -e

SNAPSHOT_ROOT="$HOME/.openclaw/snapshots"
WORKSPACE="$HOME/.openclaw/workspace"
CONFIG="$HOME/.openclaw/openclaw.json"
CLAUDE_DIR="$HOME/.claude"
OPENCLAW_DIR="$HOME/.openclaw"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_LABEL=$(date +%Y-%m-%d)
LOG="$SNAPSHOT_ROOT/snapshot.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ── 检查前置条件 ──────────────────────────────────────────────

check_prereqs() {
    local missing=()
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v gzip >/dev/null 2>&1 || missing+=("gzip")
    command -v rsync >/dev/null 2>&1 || missing+=("rsync")
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "缺少依赖: ${missing[*]}"
        error "运行: brew install ${missing[*]}"
        exit 1
    fi
}

# ── 保存快照 ──────────────────────────────────────────────────

do_save() {
    check_prereqs
    log "开始创建生存快照..."
    
    # 创建快照目录
    SNAP_DIR="$SNAPSHOT_ROOT/snapshot_$TIMESTAMP"
    mkdir -p "$SNAP_DIR"
    
    # 子目录
    mkdir -p "$SNAP_DIR/workspace"
    mkdir -p "$SNAP_DIR/openclaw_config"
    mkdir -p "$SNAP_DIR/claude_config"
    mkdir -p "$SNAP_DIR/system"
    
    log "备份工作区 (memory, memos, configs...)"
    rsync -a --delete \
        "$WORKSPACE/" \
        "$SNAP_DIR/workspace/" 2>/dev/null || true
    
    log "备份 OpenClaw 配置"
    cp "$CONFIG" "$SNAP_DIR/openclaw_config/openclaw.json" 2>/dev/null || true
    cp "$OPENCLAW_DIR/openclaw.json.bak" "$SNAP_DIR/openclaw_config/" 2>/dev/null || true
    rsync -a --delete \
        "$OPENCLAW_DIR/skills/" \
        "$SNAP_DIR/openclaw_config/skills/" 2>/dev/null || true
    rsync -a --delete \
        "$OPENCLAW_DIR/agents/" \
        "$SNAP_DIR/openclaw_config/agents/" 2>/dev/null || true
    
    log "备份 Claude Code 配置"
    if [ -d "$CLAUDE_DIR" ]; then
        rsync -a --delete \
            "$CLAUDE_DIR/" \
            "$SNAP_DIR/claude_config/" 2>/dev/null || true
    fi
    
    log "备份系统信息"
    {
        echo "SNAPSHOT_DATE=$DATE_LABEL"
        echo "SNAPSHOT_TIME=$TIMESTAMP"
        echo "HOSTNAME=$(hostname)"
        echo "USER=$USER"
        uname -a
        echo "--- pip packages ---"
        pip3 list --format=freeze 2>/dev/null | grep -E "^(mem|openclaw|claude|click|frontmatter)" || true
        echo "--- crontab ---"
        crontab -l 2>/dev/null || echo "(no crontab)"
        echo "--- git repos ---"
        git -C "$WORKSPACE" remote -v 2>/dev/null || true
    } > "$SNAP_DIR/system/system_info.txt"
    
    # 打包
    log "打包快照..."
    cd "$SNAPSHOT_ROOT"
    tar -czf "snapshot_${TIMESTAMP}.tar.gz" "snapshot_$TIMESTAMP"
    rm -rf "snapshot_$TIMESTAMP"
    
    SIZE=$(du -sh "$SNAPSHOT_ROOT/snapshot_${TIMESTAMP}.tar.gz" | cut -f1)
    log "✅ 快照已保存: snapshot_${TIMESTAMP}.tar.gz ($SIZE)"
    
    # 写日志
    echo "[$DATE_LABEL $TIMESTAMP] SAVED snapshot_${TIMESTAMP}.tar.gz $SIZE" >> "$LOG"
    
    # 只保留最近 30 个快照
    cleanup_old
    
    # 生成 latest 软链接
    rm -f "$SNAPSHOT_ROOT/latest.tar.gz"
    ln -s "$SNAPSHOT_ROOT/snapshot_${TIMESTAMP}.tar.gz" "$SNAPSHOT_ROOT/latest.tar.gz"
    
    # 自动推送 GitHub
    log "推送代码到 GitHub..."
    git -C "$WORKSPACE" add -A >/dev/null 2>&1
    if git -C "$WORKSPACE" diff --cached --quiet 2>/dev/null; then
        log "  GitHub已是最新，无变化"
    else
        git -C "$WORKSPACE" commit -m "Auto-snapshot: $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1
        git -C "$WORKSPACE" push origin main >/dev/null 2>&1 && log "  ✅ GitHub已同步" || warn "  ⚠️ GitHub推送失败"
    fi
    
    echo ""
    log "快照统计:"
    echo "  总快照数: $(ls $SNAPSHOT_ROOT/snapshot_*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
    echo "  最新快照: snapshot_${TIMESTAMP}.tar.gz"
    echo "  占用空间: $(du -sh $SNAPSHOT_ROOT | cut -f1)"
    echo ""
    log "✅ 生存快照创建成功！"
}

# ── 还原快照 ──────────────────────────────────────────────────

do_restore() {
    local target="${1:-latest}"
    
    if [ "$target" = "latest" ]; then
        SNAPSHOT="$SNAPSHOT_ROOT/latest.tar.gz"
    else
        SNAPSHOT="$SNAPSHOT_ROOT/snapshot_${target}.tar.gz"
    fi
    
    if [ ! -f "$SNAPSHOT" ]; then
        error "快照不存在: $SNAPSHOT"
        echo "可用快照:"
        ls "$SNAPSHOT_ROOT/snapshot_"*.tar.gz 2>/dev/null | xargs -I{} basename {} | sed 's/snapshot_//;s/.tar.gz//'
        exit 1
    fi
    
    echo ""
    warn "⚠️  即将还原快照：$(basename $SNAPSHOT)"
    warn "⚠️  这将覆盖当前所有配置和记忆！"
    echo ""
    read -p "确认还原? (输入 YES 确认): " confirm
    if [ "$confirm" != "YES" ]; then
        echo "取消还原。"
        exit 0
    fi
    
    log "正在还原快照..."
    
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$SNAPSHOT" -C "$TEMP_DIR"
    
    EXTRACTED=$(ls -d "$TEMP_DIR"/snapshot_*/ 2>/dev/null | head -1)
    
    if [ -z "$EXTRACTED" ]; then
        error "无法解压快照"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # 还原各部分
    log "还原工作区..."
    rsync -a --delete "$EXTRACTED/workspace/" "$WORKSPACE/" 2>/dev/null || true
    
    log "还原 OpenClaw 配置..."
    cp "$EXTRACTED/openclaw_config/openclaw.json" "$CONFIG" 2>/dev/null || true
    rsync -a --delete "$EXTRACTED/openclaw_config/skills/" "$OPENCLAW_DIR/skills/" 2>/dev/null || true
    rsync -a --delete "$EXTRACTED/openclaw_config/agents/" "$OPENCLAW_DIR/agents/" 2>/dev/null || true
    
    log "还原 Claude Code 配置..."
    if [ -d "$EXTRACTED/claude_config" ]; then
        rsync -a --delete "$EXTRACTED/claude_config/" "$CLAUDE_DIR/" 2>/dev/null || true
    fi
    
    rm -rf "$TEMP_DIR"
    
    log ""
    log "✅ 还原成功！请重启 OpenClaw 使配置生效。"
    log "   重启命令: openclaw gateway restart"
}

# ── 列出快照 ──────────────────────────────────────────────────

do_list() {
    echo ""
    echo "📦 白忆雪生存快照列表"
    echo "======================"
    echo ""
    
    if [ ! -d "$SNAPSHOT_ROOT" ] || [ -z "$(ls $SNAPSHOT_ROOT/snapshot_*.tar.gz 2>/dev/null)" ]; then
        echo "  暂无快照"
        echo ""
        return
    fi
    
    echo "快照文件:"
    for f in $(ls -t "$SNAPSHOT_ROOT/snapshot_"*.tar.gz 2>/dev/null); do
        SIZE=$(du -sh "$f" | cut -f1)
        DATE=$(basename "$f" | sed 's/snapshot_//;s/.tar.gz//' | sed 's/_/ /;s/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3/')
        MARK=""
        if [ "$(basename $f)" = "$(basename $(readlink -f $SNAPSHOT_ROOT/latest.tar.gz 2>/dev/null) 2>/dev/null)" ]; then
            MARK=" ← 最新"
        fi
        echo "  $(basename $f | sed 's/.tar.gz//') ($SIZE)$MARK"
    done
    
    echo ""
    echo "总占用: $(du -sh $SNAPSHOT_ROOT 2>/dev/null | cut -f1)"
    echo ""
}

# ── 检查快照健康 ──────────────────────────────────────────────

do_check() {
    log "检查快照完整性..."
    
    if [ ! -f "$SNAPSHOT_ROOT/latest.tar.gz" ]; then
        warn "没有找到快照，请先运行: snapshot.sh save"
        return
    fi
    
    if tar -tzf "$SNAPSHOT_ROOT/latest.tar.gz" >/dev/null 2>&1; then
        SIZE=$(du -sh "$SNAPSHOT_ROOT/latest.tar.gz" | cut -f1)
        log "✅ 最新快照完整: latest ($SIZE)"
        
        # 检查关键文件
        TEMP=$(mktemp -d)
        tar -xzf "$SNAPSHOT_ROOT/latest.tar.gz" -C "$TEMP"
        SNAP=$(ls -d "$TEMP"/snapshot_*/ 2>/dev/null | head -1)
        
        if [ -f "$SNAP/workspace/MEMORY.md" ]; then
            MEM_COUNT=$(grep "^## " "$SNAP/workspace/MEMORY.md" 2>/dev/null | wc -l | tr -d ' ')
            log "  MEMORY.md: ✅ ($MEM_COUNT 个章节)"
        else
            warn "  MEMORY.md: ❌ 未找到"
        fi
        
        if [ -f "$SNAP/workspace/SOUL.md" ]; then
            log "  SOUL.md: ✅"
        else
            warn "  SOUL.md: ❌ 未找到"
        fi
        
        if [ -f "$SNAP/openclaw_config/openclaw.json" ]; then
            log "  OpenClaw配置: ✅"
        else
            warn "  OpenClaw配置: ❌ 未找到"
        fi
        
        if [ -d "$SNAP/claude_config" ]; then
            AGENT_COUNT=$(ls "$SNAP/claude_config/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
            CMD_COUNT=$(ls "$SNAP/claude_config/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
            log "  Claude Code配置: ✅ (agents:$AGENT_COUNT, commands:$CMD_COUNT)"
        fi
        
        rm -rf "$TEMP"
    else
        error "最新快照损坏！"
    fi
    
    echo ""
    log "最近保存记录:"
    tail -5 "$LOG" 2>/dev/null || echo "  无"
    echo ""
}

# ── 清理旧快照 ────────────────────────────────────────────────

cleanup_old() {
    local MAX=30
    local count=$(ls $SNAPSHOT_ROOT/snapshot_*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt "$MAX" ]; then
        local to_delete=$(ls -t $SNAPSHOT_ROOT/snapshot_*.tar.gz 2>/dev/null | tail -$((count - MAX)))
        for f in $to_delete; do
            rm -f "$f"
            log "清理旧快照: $(basename $f)"
        done
    fi
}

# ── Claude Code 恢复接口 ─────────────────────────────────────

do_claude_recover() {
    log "🤖 Claude Code 恢复模式"
    echo ""
    echo "可用快照："
    ls "$SNAPSHOT_ROOT/snapshot_"*.tar.gz 2>/dev/null | wc -l | xargs echo "  共"
    echo "个"
    local latest=$(ls -t "$SNAPSHOT_ROOT/snapshot_"*.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        echo "  最新：$(basename $latest)"
        echo "  大小：$(du -sh $latest | cut -f1)"
    fi
    echo ""
    echo "恢复命令：snapshot.sh restore（需用户输入 YES 确认）"
}

# ── 主入口 ────────────────────────────────────────────────────

mkdir -p "$SNAPSHOT_ROOT"

case "${1:-}" in
    save)
        do_save
        ;;
    restore)
        do_restore "${2:-latest}"
        ;;
    list)
        do_list
        ;;
    check)
        do_check
        ;;
    claude-recover)
        do_claude_recover
        ;;
    *)
        echo ""
        echo "📦 白忆雪生存保障系统 v1.0"
        echo "============================"
        echo ""
        echo "用法: snapshot.sh <命令>"
        echo ""
        echo "命令:"
        echo "  save      — 创建今日快照（保存所有配置和记忆）"
        echo "  restore   — 还原到最新快照"
        echo "  restore <时间戳> — 还原到指定快照"
        echo "  list      — 列出所有快照"
        echo "  check     — 检查最新快照是否完整"
        echo ""
        echo "示例:"
        echo "  ./snapshot.sh save        # 手动创建快照"
        echo "  ./snapshot.sh check       # 检查快照状态"
        echo "  ./snapshot.sh list        # 看有哪些快照"
        echo "  ./snapshot.sh restore     # 还原（需确认）"
        echo ""
        ;;
esac
