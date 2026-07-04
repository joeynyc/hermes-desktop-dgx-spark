# Agent Instructions

Use this file when an agent is asked to configure Hermes Desktop on a Mac for DGX Spark local inference.

Do not guess model ids. Read them from `/v1/models`.
Do not broaden scope beyond Hermes Desktop on macOS and a DGX Spark OpenAI-compatible endpoint.

## Inputs

Required:

```text
SPARK_BASE_URL=http://<spark-ip>:8000/v1
MODEL_ID=<model id from /v1/models>
```

Default API key:

```text
local
```

## Execute

1. Verify the model endpoint:

   ```bash
   curl "$SPARK_BASE_URL/models"
   ```

2. Verify chat completions:

   ```bash
   scripts/check-spark.sh "$SPARK_BASE_URL" "$MODEL_ID"
   ```

   If the first chat request returns reasoning with no final content, the script retries with `chat_template_kwargs.enable_thinking=false`.

3. Save Hermes environment values in `~/.hermes/.env`:

   ```text
   OPENAI_BASE_URL=<SPARK_BASE_URL>
   OPENAI_API_KEY=local
   ```

4. Update `~/.hermes/config.yaml`:

   Preserve unrelated Hermes settings. Edit only the top-level `model` block and `providers.dgx-spark`.

   ```yaml
   model:
     provider: custom:dgx-spark
     base_url: <SPARK_BASE_URL>
     default: <MODEL_ID>

   providers:
     dgx-spark:
       name: DGX Spark
       api: <SPARK_BASE_URL>
       key_env: OPENAI_API_KEY
       default_model: <MODEL_ID>
       transport: openai_chat
   ```

5. If the model needs thinking disabled, add:

   ```yaml
       extra_body:
         chat_template_kwargs:
           enable_thinking: false
   ```

6. In Hermes Desktop, set the active composer model:

   ```text
   Model picker -> DGX Spark -> <MODEL_ID>
   ```

## Verify

The task is complete only when all are true:

```text
[ ] /v1/models returns <MODEL_ID>
[ ] /v1/chat/completions returns final assistant content
[ ] ~/.hermes/.env contains OPENAI_BASE_URL and OPENAI_API_KEY
[ ] ~/.hermes/config.yaml has model.provider custom:dgx-spark
[ ] Hermes Desktop composer shows dgx-spark:<MODEL_ID>
```

## Do Not

- Do not paste a real cloud API key. Use `local` unless the user's server requires something else.
- Do not use a model name from memory.
- Do not leave the composer on an old provider after changing settings.
- Do not add unrelated Hermes setup, skills, cron, or messaging instructions.
