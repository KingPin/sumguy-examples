from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Point at HyperDX
# OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4318"

# Point at OpenObserve
# OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:5080/api/default/"
# OTEL_EXPORTER_OTLP_HEADERS = "Authorization=Basic <base64(email:password)>"

provider = TracerProvider()
exporter = OTLPSpanExporter(
    endpoint="http://localhost:4318/v1/traces",  # swap per platform
)
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

FastAPIInstrumentor.instrument()
