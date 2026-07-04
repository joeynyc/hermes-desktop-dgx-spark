#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-}"
model_id="${2:-}"

if [[ -z "$base_url" || -z "$model_id" ]]; then
  echo "Usage: scripts/check-spark.sh http://<spark-ip>:8000/v1 <model-id>" >&2
  exit 2
fi

base_url="${base_url%/}"
models_file="$(mktemp "${TMPDIR:-/tmp}/hermes-dgx-spark-models.XXXXXX.json")"
trap 'rm -f "$models_file"' EXIT

echo "Checking models at $base_url/models"
curl -fsS "$base_url/models" | tee "$models_file" >/dev/null

if ! tr -d '[:space:]' < "$models_file" | grep -Fq "\"id\":\"$model_id\""; then
  echo "Model id not found: $model_id" >&2
  exit 1
fi

echo "Checking chat completions for $model_id"
payload_basic="$(
  cat <<JSON
{
  "model": "$model_id",
  "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
  "max_tokens": 20,
  "temperature": 0
}
JSON
)"

payload_no_thinking="$(
  cat <<JSON
{
  "model": "$model_id",
  "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
  "max_tokens": 20,
  "temperature": 0,
  "chat_template_kwargs": {
    "enable_thinking": false
  }
}
JSON
)"

request_chat() {
  curl -fsS "$base_url/chat/completions" \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer local' \
    -d "$1"
}

response="$(request_chat "$payload_basic")"

printf '%s\n' "$response"

if printf '%s' "$response" | grep -qi '"content"[[:space:]]*:[[:space:]]*"ok"'; then
  echo "OK"
  exit 0
fi

echo "Basic request did not return final content 'ok'. Retrying with enable_thinking=false." >&2
response="$(request_chat "$payload_no_thinking")"
printf '%s\n' "$response"

if printf '%s' "$response" | grep -qi '"content"[[:space:]]*:[[:space:]]*"ok"'; then
  echo "OK with chat_template_kwargs.enable_thinking=false"
  exit 0
fi

echo "Chat completion did not return exact final content: ok" >&2
exit 1
