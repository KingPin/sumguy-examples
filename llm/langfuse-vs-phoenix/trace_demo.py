"""Send the same chat completion to Langfuse or Phoenix.

Usage:
  uv run --with langfuse==5.2.0 --with openai trace_demo.py langfuse
  uv run --with arize-phoenix-otel==0.17.3 --with openinference-instrumentation-openai==0.1.69 \
      --with openai trace_demo.py phoenix
"""
import os
import sys

backend = sys.argv[1] if len(sys.argv) > 1 else "langfuse"
BASE_URL = os.environ.get("OPENAI_BASE_URL", "http://localhost:8080/v1")
API_KEY = os.environ.get("OPENAI_API_KEY", "none")
MODEL = os.environ.get("MODEL", "llama3.2")

if backend == "langfuse":
    # Drop-in wrapper: same client API, every call becomes a traced generation.
    # Reads LANGFUSE_PUBLIC_KEY, LANGFUSE_SECRET_KEY, LANGFUSE_HOST from the env.
    from langfuse import get_client, observe
    from langfuse.openai import OpenAI

    client = OpenAI(base_url=BASE_URL, api_key=API_KEY)

    @observe(name="explain-tracing")
    def ask(question: str) -> str:
        r = client.chat.completions.create(
            model=MODEL,
            messages=[{"role": "user", "content": question}],
            extra_body={"chat_template_kwargs": {"enable_thinking": False}},
        )
        return r.choices[0].message.content

    print(ask("In one sentence, what is a trace?"))
    get_client().flush()

elif backend == "phoenix":
    # OpenTelemetry plus OpenInference: patch the OpenAI SDK, export OTLP.
    # Reads PHOENIX_COLLECTOR_ENDPOINT (HTTP base URL) and PHOENIX_API_KEY from the env.
    # The endpoint is passed explicitly: without a full /v1/traces URL, register()
    # picks gRPC and dials port 4317 on that host, ignoring the port you set.
    from openinference.instrumentation.openai import OpenAIInstrumentor
    from phoenix.otel import register
    from openai import OpenAI

    endpoint = os.environ.get("PHOENIX_COLLECTOR_ENDPOINT", "http://localhost:6006")
    provider = register(
        project_name="demo",
        endpoint=endpoint.rstrip("/") + "/v1/traces",
        batch=True,
        auto_instrument=False,
    )
    OpenAIInstrumentor().instrument(tracer_provider=provider)

    client = OpenAI(base_url=BASE_URL, api_key=API_KEY)
    r = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": "In one sentence, what is a trace?"}],
        extra_body={"chat_template_kwargs": {"enable_thinking": False}},
    )
    print(r.choices[0].message.content)
    provider.force_flush()
else:
    sys.exit("usage: trace_demo.py langfuse|phoenix")
