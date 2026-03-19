#!/bin/bash
# 切换 Claude Code 的 settings.json 配置，并自动管理 LiteLLM 进程
# 用法:
#   ./switch.sh deepseek  — 切换到 DeepSeek（自动启动代理）
#   ./switch.sh default   — 切回原版（自动停止代理）
#   ./switch.sh status    — 查看当前模式
#   ./switch.sh zhipu     — 切换到智谱 GLM（自动启动代理）

SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LITELLM_PID_FILE="/tmp/litellm_proxy.pid"
LITELLM_LOG="/tmp/litellm.log"

set_env() {
  python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d.setdefault('env', {})['$1'] = '$2'
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"
}

del_env() {
  python3 -c "
import json
with open('$SETTINGS') as f:
    d = json.load(f)
d.get('env', {}).pop('$1', None)
with open('$SETTINGS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
"
}

start_litellm() {
  local config="$1"
  stop_litellm silent
  cd "$SCRIPT_DIR"
  set -a; source .env; set +a
  litellm --config "$config"
}

stop_litellm() {
  local silent="$1"
  # 先用 pid 文件
  if [ -f "$LITELLM_PID_FILE" ]; then
    local pid=$(cat "$LITELLM_PID_FILE")
    kill "$pid" 2>/dev/null && rm -f "$LITELLM_PID_FILE"
  fi
  # 再兜底杀掉所有 litellm 进程
  pkill -f "litellm.*--config" 2>/dev/null
  [ "$silent" != "silent" ] && echo "✓ LiteLLM 已停止"
  sleep 1
}

case "$1" in
  deepseek)
    set_env ANTHROPIC_BASE_URL "http://localhost:4000"
    set_env ANTHROPIC_API_KEY  "sk-1234567890"
    start_litellm "config.deepseek.yaml"
    echo "✓ 已切换到 DeepSeek 模式，重启 Claude Code 生效"
    ;;
  zhipu)
    set_env ANTHROPIC_BASE_URL "http://localhost:4000"
    set_env ANTHROPIC_API_KEY  "sk-1234567890"
    start_litellm "config.zhipu.yaml"
    echo "✓ 已切换到智谱模式，重启 Claude Code 生效"
    ;;
  default)
    stop_litellm
    set_env ANTHROPIC_BASE_URL "https://api.anthropic.com"
    del_env ANTHROPIC_API_KEY
    echo "✓ 已切回原版（直连 Anthropic），重启 Claude Code 生效"
    ;;
  status)
    BASE_URL=$(python3 -c "import json; d=json.load(open('$SETTINGS')); print(d.get('env', {}).get('ANTHROPIC_BASE_URL', '未设置'))" 2>/dev/null)
    if echo "$BASE_URL" | grep -q "localhost"; then
      if [ -f "$LITELLM_PID_FILE" ] && kill -0 "$(cat $LITELLM_PID_FILE)" 2>/dev/null; then
        echo "当前模式：LiteLLM 代理 → $BASE_URL (pid=$(cat $LITELLM_PID_FILE) 运行中)"
      else
        echo "当前模式：LiteLLM 代理 → $BASE_URL (⚠ 代理未运行)"
      fi
    else
      echo "当前模式：原版（直连 Anthropic → $BASE_URL）"
    fi
    ;;
  *)
    echo "用法: $0 {deepseek|zhipu|default|status}"
    echo ""
    echo "  deepseek  切换到 DeepSeek 模式（自动启动 LiteLLM 代理）"
    echo "  zhipu     切换到智谱 GLM 模式（自动启动 LiteLLM 代理）"
    echo "  default   切回原版 Anthropic 直连模式（自动停止代理）"
    echo "  status    查看当前使用的模式"
    exit 1
    ;;
esac
