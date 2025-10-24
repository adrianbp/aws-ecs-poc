# AWS ECS JVM Tuning POC

Esta prova de conceito demonstra uma stack completa para explorar configurações de JVM em workloads ECS Fargate.

## Componentes

- **Terraform (`terraform/`)**: Provisiona rede, cluster ECS, repositório ECR, tarefa Fargate e balanceador de carga.
- **Aplicação Spring Boot (`service/`)**: API REST simples usando Java 21 (Amazon Corretto headless) empacotada em container Amazon Linux.
- **Pipeline GitHub Actions (`.github/workflows/ecs-deploy.yml`)**: Build da aplicação, build/push da imagem para o ECR e atualização da task ECS.
- **Teste de carga k6 (`k6/load-test.js`)**: Script parametrizável para observar o impacto de diferentes configurações de JVM sob carga.

## Fluxo Geral

1. **Provisionamento** (a task inicia com `desired_count=0` por padrão; ajuste para `1` após publicar a primeira imagem)
   ```bash
   cd terraform
   terraform init
   terraform apply -var="project_name=ecs-jvm" -var="environment=dev" -var="container_image=<placeholder-image>"
   ```
   > Configure suas credenciais AWS previamente (`AWS_PROFILE`, `AWS_ACCESS_KEY_ID` etc.).
   > Use qualquer imagem válida (até mesmo uma imagem de bootstrap) apenas para registrar a primeira revisão; a esteira irá atualizar a task com a imagem definitiva.

2. **Build local da aplicação**
   ```bash
   cd service
   mvn clean package
   docker build -t <conta>.dkr.ecr.<região>.amazonaws.com/ecs-jvm:local .
   ```

3. **Pipeline GitHub Actions**
   - Crie um repositório GitHub e faça push deste diretório.
   - Configure segredos esperados pelo workflow (`AWS_ROLE_TO_ASSUME`, `AWS_REGION`, `ECR_REPOSITORY`, `ECS_CLUSTER`, `ECS_SERVICE`, `TASK_DEFINITION_FAMILY`).
   - A pipeline executará build, push e update do serviço.
   - Após a primeira execução com sucesso, ajuste `desired_count` no Terraform (ex.: `terraform apply -var="desired_count=1"`) para subir as tasks com a nova imagem.

4. **Testes de carga**
   ```bash
   k6 run k6/load-test.js --env BASE_URL=https://<alb-dns>/actuator/health
   ```

## Ajustes de JVM

A task ECS injeta a variável `JAVA_TOOL_OPTIONS`, que pode ser controlada via Terraform (`var.jvm_tool_options`) ou sobrescrita por variáveis de ambiente na ação do GitHub. Use-a para comparar configurações como `-Xmx`, `-XX:MaxRAMPercentage`, `-XX:+UseG1GC` etc.

Consulte os comentários no Terraform e no workflow para personalizar limites de CPU/Memória, estratégias de autoscaling e integrações adicionais.
