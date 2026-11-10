# promptfoo prompt tests for a ticket classifier

A small promptfoo suite that tests a support-ticket classifier prompt against a local OpenAI-compatible server (llama.cpp). Five tests mix deterministic assertions (`is-json`, `javascript`, `icontains`, `regex`, `not-contains`) with one `llm-rubric` graded by the same local model.

Article: https://sumguy.com/promptfoo-prompt-testing/

## Files

- `promptfooconfig.yaml`: provider, grader override, five tests
- `prompts/classify.txt`: the good prompt (JSON only)
- `prompts/classify-chatty.txt`: a deliberately bad variant that answers in prose, used to see the suite fail
- `github-workflow-example.yml`: GitHub Actions example (copy to `.github/workflows/`)

## Prerequisites and tested versions

- Node 24.18 (promptfoo 0.125.1 needs Node 22.22 or newer)
- promptfoo 0.125.1 (pinned via `npx`)
- An OpenAI-compatible endpoint. Tested against a llama.cpp `llama-server` running a 4.6B-parameter Q4_0 Gemma-family model with a 4096 token context.

The config uses placeholders: `http://localhost:8080/v1` and model name `my-model`. Change `apiBaseUrl` and the model id in the provider and in `defaultTest.options.provider`. For Ollama, either point `apiBaseUrl` at Ollama's OpenAI-compatible API (`http://localhost:11434/v1`) or use the native `ollama:chat:<model>` provider with `OLLAMA_BASE_URL` set. Neither Ollama route was run here.

## Run

```bash
export PROMPTFOO_DISABLE_TELEMETRY=1
npx promptfoo@0.125.1 eval -c promptfooconfig.yaml          # good prompt
echo $?                                                      # 0 when all pass
npx promptfoo@0.125.1 eval -c promptfooconfig.yaml -p file://prompts/classify-chatty.txt
echo $?                                                      # 100 when tests fail
npx promptfoo@0.125.1 view                                   # browser UI
```

## Observed results (2026-11-10)

- Good prompt: 5 of 5 passed, 11 s cold, 3 s on a cached rerun.
- Chatty prompt: 1 of 5 passed (the `llm-rubric` test passed even though the reply was prose), exit code 100.
- `--repeat 3`: 15 test cases, 15 passed.
- Without the grader override and without `OPENAI_API_KEY`, the `llm-rubric` test errors and the other four pass.

## Limits

- Single model and a single run per case: this is a syntax and behaviour check of promptfoo, not a model comparison.
- The GitHub workflow was not run on GitHub.
