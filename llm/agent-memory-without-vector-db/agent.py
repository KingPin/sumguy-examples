"""Minimal tool-calling agent with long-term memory. Stdlib only (urllib).

  OPENAI_BASE_URL=http://localhost:8080/v1 MODEL=your-model \
    python3 agent.py --backend fts "I switched my editor to Helix"
"""
import argparse
import json
import os
import urllib.request

from memory_files import FileMemory
from memory_fts import FtsMemory

BASE = os.environ.get("OPENAI_BASE_URL", "http://localhost:8080/v1")
MODEL = os.environ.get("MODEL", "local")

TOOLS = [
    {"type": "function", "function": {
        "name": "remember",
        "description": "Save or update one durable fact, preference, or decision (with its reason). Reuse a key to update.",
        "parameters": {"type": "object", "properties": {
            "key": {"type": "string", "description": "short-kebab-case id"},
            "description": {"type": "string", "description": "one-line summary"},
            "body": {"type": "string", "description": "the fact, plus why"}},
            "required": ["key", "description", "body"]}}},
    {"type": "function", "function": {
        "name": "recall",
        "description": "Search saved memories by keywords.",
        "parameters": {"type": "object", "properties": {
            "query": {"type": "string"}}, "required": ["query"]}}},
    {"type": "function", "function": {
        "name": "forget",
        "description": "Delete a memory that is wrong or stale.",
        "parameters": {"type": "object", "properties": {
            "key": {"type": "string"}}, "required": ["key"]}}},
]


def chat(messages):
    body = {"model": MODEL, "messages": messages, "tools": TOOLS,
            "chat_template_kwargs": {"enable_thinking": False}}
    req = urllib.request.Request(
        f"{BASE}/chat/completions", json.dumps(body).encode(),
        {"Content-Type": "application/json",
         "Authorization": "Bearer " + os.environ.get("OPENAI_API_KEY", "none")})
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.load(r)["choices"][0]["message"]


def run_tool(mem, name, args):
    if name == "remember":
        return mem.remember(args["key"], args["description"], args["body"])
    if name == "recall":
        return json.dumps(mem.recall(args["query"]))
    if name == "forget":
        return mem.forget(args["key"])
    return f"unknown tool {name}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", choices=["files", "fts"], default="files")
    ap.add_argument("--dir", default="agent_memory")
    ap.add_argument("prompt")
    a = ap.parse_args()
    os.makedirs(a.dir, exist_ok=True)
    mem = FileMemory(a.dir) if a.backend == "files" else FtsMemory(f"{a.dir}/memory.db")

    system = ("You are a personal assistant with long-term memory. Save durable facts, "
              "preferences, and decisions with remember. Use recall before answering "
              "questions about the user. Use forget when a memory is wrong.")
    # The files backend keeps its index in the prompt. FTS keeps it behind recall.
    if a.backend == "files":
        system += "\n\nMemory index:\n" + (mem.index() or "(empty)")
    messages = [{"role": "system", "content": system}, {"role": "user", "content": a.prompt}]

    for _ in range(6):  # hard cap on tool rounds
        msg = chat(messages)
        messages.append(msg)
        if not msg.get("tool_calls"):
            print(msg.get("content", ""))
            return
        for call in msg["tool_calls"]:
            fn = call["function"]
            result = run_tool(mem, fn["name"], json.loads(fn["arguments"]))
            print(f"[tool] {fn['name']}({fn['arguments']}) -> {result[:120]}")
            messages.append({"role": "tool", "tool_call_id": call["id"], "content": result})
    print("(stopped: tool round limit)")


if __name__ == "__main__":
    main()
