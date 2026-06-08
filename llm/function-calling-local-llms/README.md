# Function Calling in Local LLMs

A minimal local agent that uses **function calling** (tool use) with a model
running on [Ollama](https://ollama.com). The model decides which tools to call,
your code executes them, and the results are fed back until the model produces
a final answer.

Two mock tools are included:
- `get_weather` — looks up canned weather for a few cities
- `calculator` — basic arithmetic

## What it does

```text
[User] What's the weather in Portland, OR? Then add 5 to that temperature.
[Tool Call] get_weather({'location': 'Portland, OR', 'unit': 'fahrenheit'})
[Tool Result] The weather in Portland, OR is cloudy, 62°F.
[Tool Call] calculator({'operation': 'add', 'a': 62, 'b': 5})
[Tool Result] 62 add 5 = 67
[Agent] The weather in Portland, OR is cloudy with a temperature of 62°F.
        Adding 5 to that would be 67°F.
```

## Prerequisites

Tested with:

| Component | Version |
|-----------|---------|
| Ollama    | 0.4+    |
| Python    | 3.10+   |
| `ollama` (Python lib) | 0.4+ |
| Model     | `gemma4:e4b` |

You need a model that's **actually trained for tool use** — Gemma 4, Qwen3,
Llama 4/3.3. Older models (Llama 2, base Mistral 7B) will not emit `tool_calls`
and the agent will just chat back instead of calling a tool.

## How to run it

```bash
# 1. Pull a tool-capable model and start the server
ollama pull gemma4:e4b
ollama serve            # (skip if Ollama already runs as a service)

# 2. Install the Python client
pip install -r requirements.txt

# 3. Run the agent
python agent.py
```

Want a different model? Edit the `MODEL` constant at the top of `agent.py`
(e.g. `"qwen3"` for the most stable tool calling, or a larger `gemma4` size if
you have the VRAM).

## From the article

Full write-up — formats, GBNF grammar constraints, MCP vs. function calling,
and the common failure modes — on the blog:

**https://sumguy.com/function-calling-local-llms/**
