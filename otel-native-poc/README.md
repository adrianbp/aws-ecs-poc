# OpenTelemetry Native Proof of Concept

This proof of concept demonstrates a Spring Boot 3.5 native application using the
OpenTelemetry Spring Boot starter to collect HTTP and JDBC spans from an
in-memory H2 database. Spans are exported via OTLP so they can be ingested by
Dynatrace (or any OTLP-compatible backend).

## Project layout

- `pom.xml` – Spring Boot application with OpenTelemetry starter, OTLP exporter,
  and GraalVM native image profile.
- `src/main/java/com/example/otel` – REST controller backed by H2 via
  `JdbcTemplate`. Repository methods are annotated with `@WithSpan` to guarantee
  span creation even when automatic JDBC instrumentation is limited in native
  images.
- `src/main/resources/application.properties` – Datasource setup plus default
  OpenTelemetry resource attributes and exporter configuration.

## Running on the JVM

```bash
cd otel-native-poc
./mvnw spring-boot:run \
  -DOTEL_EXPORTER_OTLP_ENDPOINT="https://<your-dynatrace-endpoint>/api/v2/otlp" \
  -DOTEL_EXPORTER_OTLP_HEADERS="Authorization=Api-Token <token>"
```

### Dynatrace-specific environment

| Variable | Example | Notes |
| --- | --- | --- |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<tenant>.live.dynatrace.com/api/v2/otlp` | Use the OTLP ingest endpoint for your environment |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Api-Token dt0c01...` | Token must include the *Ingest OpenTelemetry traces* scope |
| `OTEL_RESOURCE_ATTRIBUTES` | `service.name=otel-native-poc,deployment.environment=dev` | Overrides the defaults shipped in `application.properties` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | Dynatrace OTLP ingest expects the HTTP/protobuf protocol |
| `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE` | `delta` | Matches Dynatrace guidance for OTLP metrics temporality |

When the service is up, exercise the REST API to generate spans:

```bash
curl http://localhost:8080/api/greetings
curl http://localhost:8080/api/greetings/1
```

## Building a native executable

The project includes a GraalVM profile. You need GraalVM 25 with the native
image component installed.

```bash
cd otel-native-poc
mvn -Pnative -DskipTests clean package
```

The resulting binary `target/otel-native-poc` can be run with the same OTLP
variables:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT="https://<tenant>.live.dynatrace.com/api/v2/otlp" \
OTEL_EXPORTER_OTLP_HEADERS="Authorization=Api-Token <token>" \
./target/otel-native-poc
```

> **Note**: GraalVM native images do not support the full set of automatic
> instrumentation available on the JVM. Manual spans (via `@WithSpan`) ensure
> database access remains observable in this proof of concept.

## Next steps

- Adjust `OTEL_RESOURCE_ATTRIBUTES` for the desired service metadata.
- Adjust sampling or add additional instrumentation (metrics, logs) as needed
  once data is visible in Dynatrace.
- Containerize the native binary and deploy it alongside the existing ECS
  services for comparison with the Dynatrace-native agent approach.
