# Use DGX Spark Local Models in Hermes Desktop

Connect Hermes Agent Desktop on macOS to an OpenAI-compatible inference server running on a DGX Spark.

This guide is for this setup:

```text
Mac running Hermes Desktop
        |
        | HTTP over Tailscale or LAN
        v
DGX Spark running local inference
http://<spark-ip>:8000/v1
```

Hermes Desktop uses the same Hermes config and API keys as the CLI/TUI. That means the Desktop UI and `~/.hermes/config.yaml` are both valid ways to configure the same agent.

Official reference: https://hermes-agent.nousresearch.com/docs/user-guide/desktop

## Humans vs Agents

Humans: follow this README from top to bottom.

Agents: read [`AGENTS.md`](AGENTS.md), run the verifier, update `~/.hermes/.env`, update `~/.hermes/config.yaml`, then confirm the Hermes Desktop composer model.

## 1. Pick The Spark URL

Use the Tailscale IP when the Mac and DGX Spark are both on Tailscale:

```text
http://100.70.19.106:8000/v1
```

Use the LAN IP when both machines are on the same local network and you prefer local routing:

```text
http://192.168.1.15:8000/v1
```

In the commands below, replace `SPARK_BASE_URL` with your URL.

## 2. Confirm The Mac Can Reach The Spark

```bash
curl http://100.70.19.106:8000/v1/models
```

Expected result: JSON with at least one model object.

Copy the model `id`:

```json
{
  "id": "aeon-ultimate"
}
```

Use your returned model id everywhere this guide says `MODEL_ID`.

## 3. Test The Model Before Hermes

Fast path:

```bash
scripts/check-spark.sh http://100.70.19.106:8000/v1 MODEL_ID
```

The script checks `/v1/models`, sends a chat request, and retries with `enable_thinking:false` if the first response contains no final content.

Manual test:

```bash
curl http://100.70.19.106:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer local' \
  -d '{
    "model": "MODEL_ID",
    "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
    "max_tokens": 20,
    "temperature": 0
  }'
```

Expected result: the assistant message contains `ok`.

If this fails, fix the Spark server, IP, port, firewall, Tailscale, or model id before changing Hermes.

## 4. Add The Endpoint In Hermes Desktop

Open Hermes Desktop on the Mac.

```text
Settings -> Providers -> API keys -> OpenAI API
```

Set:

```text
API key: local
OpenAI API base URL override: http://100.70.19.106:8000/v1
```

Save both fields.

## 5. Add A Named DGX Spark Provider

Edit:

```text
~/.hermes/config.yaml
```

Add or update this block:

```yaml
model:
  provider: custom:dgx-spark
  base_url: http://100.70.19.106:8000/v1
  default: MODEL_ID

providers:
  dgx-spark:
    name: DGX Spark
    api: http://100.70.19.106:8000/v1
    key_env: OPENAI_API_KEY
    default_model: MODEL_ID
    transport: openai_chat
```

Replace `MODEL_ID` with the exact id from `/v1/models`.

Example:

```yaml
default: aeon-ultimate
```

## 6. Select The Model In The Composer

Hermes Desktop can keep the current chat on an older model even after settings change.

In the message composer, click the model picker and select:

```text
DGX Spark -> MODEL_ID
```

The composer should show:

```text
Model · dgx-spark: MODEL_ID
```

## Thinking Models

Some local reasoning models may return reasoning but little or no final content on short prompts.

If your Spark server supports `chat_template_kwargs`, add this under the named provider:

```yaml
    extra_body:
      chat_template_kwargs:
        enable_thinking: false
```

Then test directly:

```bash
curl http://100.70.19.106:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer local' \
  -d '{
    "model": "MODEL_ID",
    "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
    "max_tokens": 20,
    "temperature": 0,
    "chat_template_kwargs": {
      "enable_thinking": false
    }
  }'
```

## Known-Good Checklist

```text
[ ] curl /v1/models returns the model id
[ ] curl /v1/chat/completions returns final content
[ ] Hermes saved OPENAI_API_KEY=local
[ ] Hermes saved OPENAI_BASE_URL=http://<spark-ip>:8000/v1
[ ] ~/.hermes/config.yaml has provider custom:dgx-spark
[ ] Hermes composer shows dgx-spark: MODEL_ID
```

## Troubleshooting

`curl: Operation timed out`

The Mac cannot reach the Spark. Check Tailscale, LAN IP, firewall, and port `8000`.

`model not found`

The model id in Hermes does not exactly match `/v1/models`.

Hermes still uses the old model

Change the composer model picker. Settings apply to new sessions; the active chat can stay on its previous model.

Responses contain reasoning but no answer

Add `extra_body.chat_template_kwargs.enable_thinking: false` to the named provider, then restart or reselect the model.
