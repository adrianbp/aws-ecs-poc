# Build stage: compila o projeto usando Maven com Corretto 21
FROM maven:3.9.8-amazoncorretto-21 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests clean package

# Runtime stage: Amazon Corretto 21 (Amazon Linux 2)
FROM amazoncorretto:21-al2-jdk
RUN yum update -y \
    && yum install -y curl \
    && yum clean all \
    && rm -rf /var/cache/yum

WORKDIR /app
COPY --from=build /workspace/target/ecs-demo-0.0.1-SNAPSHOT.jar app.jar

# Instala o agente Java do Datadog para APM
RUN mkdir -p /opt/datadog \
    && curl -sSL https://dtdg.co/latest-java-tracer -o /opt/datadog/dd-java-agent.jar

ENV SERVER_PORT=8080
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_TOOL_OPTIONS -jar app.jar"]
