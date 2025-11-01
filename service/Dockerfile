# Build stage: compila o projeto usando Maven com Temurin 25
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests clean package

# Runtime stage: Eclipse Temurin 25 (Ubuntu Jammy)
FROM eclipse-temurin:25-jre-jammy
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /workspace/target/ecs-demo-0.0.1-SNAPSHOT.jar app.jar

# Instala o agente Java do Datadog para APM
RUN mkdir -p /opt/datadog \
    && curl -sSL https://dtdg.co/latest-java-tracer -o /opt/datadog/dd-java-agent.jar

ENV SERVER_PORT=8080
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_TOOL_OPTIONS -jar app.jar"]
