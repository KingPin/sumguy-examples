"""
Local function-calling agent using Ollama + Gemma 4.

Takes a natural-language question, lets the model decide which tools to call
(a mock weather API and a calculator), executes them, and feeds the results
back until the model produces a final answer.

Article: https://sumguy.com/function-calling-local-llms/
"""

import json

from ollama import Client

# Initialize Ollama client
client = Client(host="http://localhost:11434")

# The model must be one trained for tool use. Gemma 4 has native function
# calling across the whole family; swap for "qwen3" if you want the most
# stable tool calling, or a larger Gemma 4 size if you have the VRAM.
MODEL = "gemma4:e4b"

# Define tools schema (OpenAI format — Ollama mirrors this)
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the current weather in a specified location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "City name or city, state",
                    },
                    "unit": {
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"],
                        "description": "Temperature unit",
                    },
                },
                "required": ["location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculator",
            "description": "Perform basic arithmetic operations",
            "parameters": {
                "type": "object",
                "properties": {
                    "operation": {
                        "type": "string",
                        "enum": ["add", "subtract", "multiply", "divide"],
                        "description": "The arithmetic operation",
                    },
                    "a": {"type": "number", "description": "First number"},
                    "b": {"type": "number", "description": "Second number"},
                },
                "required": ["operation", "a", "b"],
            },
        },
    },
]


# Fake tool implementations
def get_weather(location, unit="fahrenheit"):
    """Mock weather API."""
    weather_db = {
        "seattle, wa": {"temp": 58, "condition": "rainy"},
        "portland, or": {"temp": 62, "condition": "cloudy"},
        "san francisco, ca": {"temp": 72, "condition": "sunny"},
    }
    data = weather_db.get(location.lower(), {"temp": 70, "condition": "unknown"})
    return f"The weather in {location} is {data['condition']}, {data['temp']}°{unit[0].upper()}."


def calculator(operation, a, b):
    """Simple calculator."""
    ops = {
        "add": a + b,
        "subtract": a - b,
        "multiply": a * b,
        "divide": a / b if b != 0 else None,
    }
    result = ops.get(operation)
    if result is None:
        return "Error: division by zero"
    return f"{a} {operation} {b} = {result}"


# Tool execution dispatcher
def execute_tool(tool_name, args):
    """Call the actual tool based on name and args."""
    if tool_name == "get_weather":
        return get_weather(**args)
    elif tool_name == "calculator":
        return calculator(**args)
    return f"Unknown tool: {tool_name}"


# Main agent loop
def run_agent(user_query, max_iterations=5):
    """Run the agent with function calling."""
    messages = [{"role": "user", "content": user_query}]

    print(f"\n[User] {user_query}")

    iteration = 0
    while iteration < max_iterations:
        iteration += 1

        # Call the model with tools
        response = client.chat(
            model=MODEL,
            messages=messages,
            tools=tools,
            stream=False,
        )

        # Check if model wants to call a tool
        assistant_message = response["message"]

        if not assistant_message.get("tool_calls"):
            # No tool calls, model gave a direct answer
            print(f"[Agent] {assistant_message['content']}")
            return assistant_message["content"]

        # Process tool calls (a list — handles parallel calls too)
        tool_results = []
        for tool_call in assistant_message["tool_calls"]:
            tool_name = tool_call["function"]["name"]
            tool_args = tool_call["function"]["arguments"]

            # Parse arguments (handle both string and dict formats)
            if isinstance(tool_args, str):
                tool_args = json.loads(tool_args)

            print(f"[Tool Call] {tool_name}({tool_args})")

            # Execute the tool
            tool_result = execute_tool(tool_name, tool_args)
            print(f"[Tool Result] {tool_result}")

            tool_results.append(
                {
                    "tool_call_id": tool_call.get("id", tool_name),
                    "tool_name": tool_name,
                    "content": tool_result,
                }
            )

        # Add assistant message and tool results back to conversation
        messages.append(assistant_message)

        for result in tool_results:
            messages.append(
                {
                    "role": "tool",
                    "content": result["content"],
                    "tool_call_id": result["tool_call_id"],
                }
            )

    return "Max iterations reached without answer"


# Test it
if __name__ == "__main__":
    result = run_agent(
        "What's the weather in Portland, OR? Then add 5 to that temperature."
    )
    print(f"\n[Final Answer] {result}")
