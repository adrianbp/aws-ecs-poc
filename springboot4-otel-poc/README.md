# Spring Boot 4 OpenTelemetry Native POC

Esta prova de conceito exercita o Spring Boot 4.0.0 (lançado em novembro/2025) com o novo `spring-boot-starter-opentelemetry`, gerando um binário nativo com GraalVM.

## Execução local


```bash
cd springboot4-otel-poc
mvn spring-boot:run
```

Para um build nativo (requer GraalVM 25+):

```bash
mvn -Pnative native:compile
```

## Configuração OpenTelemetry

A aplicação exporta traces, métricas e logs via OTLP. Ajuste `src/main/resources/application.properties` com o endpoint e cabeçalhos.

## Integração com AWS CodeBuild

O arquivo `buildspec-native.yml` descreve o pipeline para gerar a imagem nativa.

1. Crie um projeto **AWS CodeBuild** apontando para este repositório (fonte GitHub) e buildspec `springboot4-otel-poc/buildspec-native.yml`.
2. Use ambiente **LINUX_CONTAINER** com build image `aws/codebuild/standard:7.0` (ou superior) e `computeType` `BUILD_GENERAL1_LARGE` (8 vCPU, ~16 GB RAM).
3. Habilite variáveis de ambiente quando necessário (`OTEL_EXPORTER_OTLP_ENDPOINT`, etc.).
4. Armazene no GitHub Secrets os valores `AWS_CODEBUILD_ROLE_ARN` (role assumida pelo workflow) e `AWS_CODEBUILD_PROJECT_NAME`.

O workflow `.github/workflows/codebuild-native-springboot4.yml` inicia o build CodeBuild on-demand (`workflow_dispatch`) ou em pushes que tocam o diretório. Ajuste a região se necessário.
