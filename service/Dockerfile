# Build stage: compila o projeto usando Maven com Corretto 21
FROM maven:3.9.8-amazoncorretto-21 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests clean package

# Runtime stage: Amazon Linux com Corretto 21 headless
FROM amazonlinux:2023
RUN dnf update -y \
    && dnf install -y java-21-amazon-corretto-headless \
    && dnf clean all \
    && rm -rf /var/cache/dnf

WORKDIR /app
COPY --from=build /workspace/target/ecs-demo-0.0.1-SNAPSHOT.jar app.jar

ENV SERVER_PORT=8080
EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c", "java $JAVA_TOOL_OPTIONS -jar app.jar"]
