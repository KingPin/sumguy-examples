from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Change this endpoint to switch between tools:
# Jaeger:  http://localhost:4317
# SigNoz:  http://localhost:4317 (same port, different backend)
exporter = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)

provider = TracerProvider()
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("my-service")

with tracer.start_as_current_span("do-the-thing") as span:
    span.set_attribute("user.id", "42")
    span.set_attribute("item.count", 7)
    # your actual logic here
