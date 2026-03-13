# LiteLLM Config — Cheap Token Setup for Claude Code

Use LiteLLM as a proxy between Claude Code and LLM providers to control costs, add GLM fallback for reliability, and optionally bring your own API key (BYOK).

## Why Use This?

- **Claude primary** — Use Anthropic models (Haiku/Sonnet/Opus) via API
- **GLM fallback** — When Claude hits rate limits (429) or fails, auto-fallback to 智谱 GLM-4.7 / GLM-4.6
- **Retries & cooldown** — `num_retries`, `retry_after`, `cooldown_time` for resilient routing
- **Cost tracking** — Centralized logging and usage visibility
- **BYOK** — Pay Anthropic directly while still using LiteLLM routing and tracking

## Quick Start

### 1. Install LiteLLM

```bash
pip install 'litellm[proxy]'
```

### 2. Config Overview

`config.yaml` includes:

- **Claude (`claude/*`)** — Primary models, requires `ANTHROPIC_API_KEY`
- **GLM (`glm/glm-4.7`, `glm/glm-4.6`)** — Fallback via 智谱 open.bigmodel.cn, requires `ZHIPU_API_KEY`
- **Fallbacks** — `claude/*` → `glm/glm-4.7` → `glm/glm-4.6` on failure/429
- **Retries** — 2 retries, 60s wait on rate limit, 600s request timeout
- **Router** — Pre-call checks, 60s cooldown before retrying primary model

### 3. Set Environment Variables

```bash
export ANTHROPIC_API_KEY="your-anthropic-api-key"
export ZHIPU_API_KEY="your-zhipu-api-key"           # 智谱 API key from open.bigmodel.cn
export LITELLM_MASTER_KEY="sk-1234567890"           # Generate a secure random key
```

### 4. Start the Proxy

```bash
litellm --config config.yaml
# RUNNING on http://0.0.0.0:4000
```

### 5. Configure Claude Code

```bash
export ANTHROPIC_BASE_URL="http://0.0.0.0:4000"
export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"

# Optional: default to Haiku for cheaper sessions
export ANTHROPIC_DEFAULT_SONNET_MODEL=claude-haiku-4-5-20251001
```

### 6. Run Claude Code

```bash
# Start with Haiku (cheapest)
claude --model claude-haiku-4-5-20251001

# Or switch models during a session
/model claude-sonnet-4-5-20250929
/model claude-haiku-4-5-20251001

# When Claude hits 429, LiteLLM auto-fallbacks to GLM
/model glm/glm-4.7
```

## Fallback Behavior

| Trigger              | Action                                                |
|----------------------|--------------------------------------------------------|
| Claude 429 / failure | Retry 2× with 60s wait → fallback to `glm/glm-4.7`    |
| GLM-4.7 fails        | Fallback to `glm/glm-4.6`                             |
| Cooldown             | After 3 fails in 1 min, model cooldowns 60s, then retry |

## Cost-Saving Tips

| Model   | Input ($/1M) | Output ($/1M) | Use For                    |
|---------|--------------|---------------|----------------------------|
| Haiku   | $0.80        | $4.00         | Simple edits, quick Q&A    |
| Sonnet  | $3.00        | $15.00        | Code review, refactors     |
| Opus    | $15.00       | $75.00        | Complex reasoning, design  |
| GLM-4.7 | $0.60        | $2.20         | Fallback when Claude 429   |

- **Default to Haiku** — Use Sonnet/Opus only when quality matters
- **Use `/model`** — Switch up for hard tasks, switch down for routine work
- **GLM fallback** — Cheaper than Claude; auto-used on rate limits

## Bring Your Own Key (BYOK)

If you want to pay Anthropic directly instead of through the proxy:

1. **Config** — Add `forward_llm_provider_auth_headers: true` and omit `api_key` in model params:

```yaml
model_list:
  - model_name: claude-sonnet-4-5-20250929
    litellm_params:
      model: anthropic/claude-sonnet-4-5-20250929
      # No api_key — client's key from /login is used

litellm_settings:
  forward_llm_provider_auth_headers: true
  master_key: os.environ/LITELLM_MASTER_KEY
```

2. **Claude Code** — Use `ANTHROPIC_CUSTOM_HEADERS` for proxy auth:

```bash
export ANTHROPIC_BASE_URL="http://0.0.0.0:4000"
export ANTHROPIC_CUSTOM_HEADERS="x-litellm-api-key: sk-your-virtual-key"
```

3. **Login** — Run `claude` and use `/login` with your Anthropic account. Your key is sent as `x-api-key` and forwarded to Anthropic.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Claude Code not connecting | Check `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and proxy: `curl http://0.0.0.0:4000/health` |
| 401 from proxy | Ensure `ANTHROPIC_AUTH_TOKEN` matches `LITELLM_MASTER_KEY` |
| Model not found | Model name in Claude Code must match `model_name` in `config.yaml` |
| BYOK: invalid x-api-key | Complete `/login` in Claude Code and set `forward_llm_provider_auth_headers: true` |
| GLM fallback fails | Verify `ZHIPU_API_KEY` and `api_base: https://open.bigmodel.cn/api/paas/v4`; try `/api/anthropic` if using Anthropic-compatible endpoint |
| Wildcard `claude/*` not working | Use explicit `model_name` entries (e.g. `claude-haiku-4-5-20251001`) in `config.yaml` |

## References

- [LiteLLM Claude Code Quickstart](https://docs.litellm.ai/docs/tutorials/claude_responses_api)
- [Claude Code with BYOK](https://docs.litellm.ai/docs/tutorials/claude_code_byok)
- [Anthropic Claude Code LLM Gateway](https://docs.anthropic.com/en/docs/claude-code/llm-gateway)
