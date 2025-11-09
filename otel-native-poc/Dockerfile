# Build stage: compiles the native executable with GraalVM
FROM container-registry.oracle.com/graalvm/native-image:25-muslib  AS build

ARG MAVEN_VERSION=3.9.9
ENV MAVEN_HOME=/opt/apache-maven-${MAVEN_VERSION}
ENV PATH=${MAVEN_HOME}/bin:${PATH}
ENV MAVEN_CONFIG=/root/.m2

RUN microdnf install -y curl tar gzip && microdnf clean all && \
    curl -fsSL https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
      | tar -xz -C /opt

WORKDIR /workspace
COPY pom.xml .
COPY src ./src

RUN mvn -B -ntp -Pnative -DskipTests clean package

# Runtime stage: minimal distroless base with non-root user
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=build /workspace/target/otel-native-poc /app/otel-native-poc
EXPOSE 8080
ENTRYPOINT ["/app/otel-native-poc"]
