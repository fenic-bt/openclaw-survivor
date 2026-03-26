#!/usr/bin/env python3
"""
OpenClaw Survivor — 濒死检测器
监控 OpenClaw 健康状态，发现异常立即告警

运行方式：
  python3 watchdog.py              # 检查一次
  python3 watchdog.py --daemon      # 持续监控（每5分钟一次）
"""

import os
import sys
import json
import hashlib
import time
import argparse
from pathlib import Path
from datetime import datetime, timezone

WORKSPACE = Path.home() / ".openclaw" / "workspace"
CONFIG = Path.home() / ".openclaw" / "openclaw.json"
SNAPSHOT_ROOT = Path.home() / ".openclaw" / "snapshots"
CHECK_INTERVAL = 300  # 5分钟


def check_memory_integrity():
    """检查 MEMORY.md 是否正常。"""
    memory_path = WORKSPACE / "MEMORY.md"
    if not memory_path.exists():
        return False, "MEMORY.md 不存在"
    
    content = memory_path.read_text()
    
    # 检查基本标记
    essential = ["云瑞", "身份", "团队"]
    missing = [e for e in essential if e not in content]
    if missing:
        return False, f"MEMORY.md 内容异常，缺少: {missing}"
    
    # 检查乱码
    try:
        content.encode('utf-8')
    except UnicodeEncodeError:
        return False, "MEMORY.md 包含无法编码的内容（可能损坏）"
    
    # 检查是否为空
    if len(content.strip()) < 100:
        return False, f"MEMORY.md 内容过少（{len(content)} 字符），可能丢失"
    
    return True, f"正常（{len(content)} 字符）"


def check_openclaw_config():
    """检查 OpenClaw 配置是否正常。"""
    if not CONFIG.exists():
        return False, "openclaw.json 不存在"
    
    try:
        content = CONFIG.read_text()
        json.loads(content)
        return True, "配置正常"
    except json.JSONDecodeError:
        return False, "openclaw.json 格式损坏"


def check_soul_integrity():
    """检查 SOUL.md 是否正常。"""
    soul_path = WORKSPACE / "SOUL.md"
    if not soul_path.exists():
        return False, "SOUL.md 不存在"
    
    content = soul_path.read_text()
    if len(content.strip()) < 50:
        return False, f"SOUL.md 内容过少"
    
    return True, f"正常（{len(content)} 字符）"


def check_snapshot_health():
    """检查最近快照是否健康。"""
    latest = SNAPSHOT_ROOT / "latest.tar.gz"
    if not latest.exists():
        return False, "没有找到快照文件"
    
    try:
        import subprocess
        result = subprocess.run(
            ["tar", "-tzf", str(latest)],
            capture_output=True, timeout=30
        )
        if result.returncode == 0:
            output = result.stdout
            if isinstance(output, bytes):
                output = output.decode("utf-8", errors="replace")
            files = output.strip().split("\n")
            # 检查关键文件是否在快照中
            critical = [f for f in files if "MEMORY.md" in f or "SOUL.md" in f]
            if critical:
                return True, f"快照包含 {len(files)} 个文件"
            else:
                return False, "快照缺少关键文件"
        else:
            return False, "快照文件损坏（无法解压）"
    except Exception as e:
        return False, f"快照检查失败: {e}"


def check_disk_space():
    """检查磁盘空间是否充足。"""
    try:
        import shutil
        stat = shutil.disk_usage("/")
        pct = stat.used / stat.total * 100
        if pct > 95:
            return False, f"磁盘空间不足（已用 {pct:.1f}%）"
        if pct > 85:
            return True, f"磁盘空间紧张（已用 {pct:.1f}%）⚠️"
        return True, f"磁盘空间正常（已用 {pct:.1f}%）"
    except:
        return True, "磁盘检查跳过"


def run_health_check() -> dict:
    """执行完整健康检查。"""
    checks = [
        ("MEMORY.md 完整性", check_memory_integrity),
        ("SOUL.md 完整性", check_soul_integrity),
        ("OpenClaw 配置", check_openclaw_config),
        ("快照健康", check_snapshot_health),
        ("磁盘空间", check_disk_space),
    ]
    
    results = []
    all_ok = True
    
    for name, fn in checks:
        try:
            ok, detail = fn()
            results.append({"check": name, "ok": ok, "detail": detail})
            if not ok:
                all_ok = False
        except Exception as e:
            results.append({"check": name, "ok": False, "detail": f"检查异常: {e}"})
            all_ok = False
    
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "all_ok": all_ok,
        "results": results,
    }


def print_report(report: dict):
    """打印健康报告。"""
    status = "✅ 健康" if report["all_ok"] else "❌ 异常"
    print(f"\n{'='*50}")
    print(f"  OpenClaw Survivor — 健康检查")
    print(f"  时间: {report['timestamp']}")
    print(f"  状态: {status}")
    print(f"{'='*50}")
    
    for r in report["results"]:
        icon = "✅" if r["ok"] else "❌"
        print(f"  {icon} {r['check']}: {r['detail']}")
    
    print()
    
    if not report["all_ok"]:
        print("⚠️  检测到异常！")
        print("   建议：")
        print(f"   1. 创建快照: ~/.openclaw/workspace/scripts/snapshot.sh save")
        print(f"   2. 如果问题严重: snapshot.sh restore")
        print()
        
        # 写告警日志
        alert_log = SNAPSHOT_ROOT / "alert.log"
        with open(alert_log, "a") as f:
            f.write(f"[{report['timestamp']}] ALERT: {[r['check'] for r in report['results'] if not r['ok']]}\n")
    else:
        print("✅ 所有检查通过，白忆雪状态正常。")
        print()


def daemon_mode(interval: int = CHECK_INTERVAL):
    """持续监控模式。"""
    print(f"启动持续监控模式（每 {interval} 秒检查一次）")
    print("按 Ctrl+C 停止\n")
    
    consecutive_failures = 0
    ALERT_THRESHOLD = 2
    
    while True:
        report = run_health_check()
        
        if not report["all_ok"]:
            consecutive_failures += 1
            if consecutive_failures >= ALERT_THRESHOLD:
                print_report(report)
                consecutive_failures = 0
        else:
            if consecutive_failures > 0:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 状态恢复: ✅")
            consecutive_failures = 0
        
        time.sleep(interval)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OpenClaw Survivor 健康检查")
    parser.add_argument("--daemon", action="store_true", help="持续监控模式")
    parser.add_argument("--interval", type=int, default=CHECK_INTERVAL, help=f"监控间隔（秒，默认{CHECK_INTERVAL}）")
    args = parser.parse_args()
    
    if args.daemon:
        daemon_mode(args.interval)
    else:
        report = run_health_check()
        print_report(report)
        sys.exit(0 if report["all_ok"] else 1)
