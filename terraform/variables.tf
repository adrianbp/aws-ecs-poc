variable "project_name" {
  description = "Nome base do projeto usado na nomenclatura dos recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente lógico (ex: dev, qa, prod)"
  type        = string
}

variable "region" {
  description = "Região AWS alvo"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de CIDRs para as subnets públicas"
  type        = list(string)
  default = [
    "10.20.0.0/24",
    "10.20.1.0/24"
  ]
}

variable "availability_zones" {
  description = "Zonas de disponibilidade a serem utilizadas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "desired_count" {
  description = "Quantidade de tarefas ECS desejadas"
  type        = number
  default     = 0
}

variable "native_service_enabled" {
  description = "Habilita o provisionamento da versão nativa"
  type        = bool
  default     = false
}

variable "native_desired_count" {
  description = "Quantidade de tarefas ECS desejadas para o serviço nativo"
  type        = number
  default     = 0
}

variable "task_cpu" {
  description = "CPU (em unidades vCPU) para a task Fargate"
  type        = number
  default     = 512
}

variable "native_task_cpu" {
  description = "CPU (em unidades vCPU) da task Fargate nativa"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memória (MB) para a task Fargate"
  type        = number
  default     = 1024
}

variable "native_task_memory" {
  description = "Memória (MB) da task Fargate nativa"
  type        = number
  default     = 1024
}

variable "dynatrace_service_enabled" {
  description = "Habilita o provisionamento da versão monitorada com Dynatrace"
  type        = bool
  default     = false
}

variable "dynatrace_desired_count" {
  description = "Quantidade de tarefas ECS desejadas para o serviço Dynatrace"
  type        = number
  default     = 0
}

variable "dynatrace_container_image" {
  description = "Imagem do container para o serviço Dynatrace"
  type        = string
  default     = null
}

variable "dynatrace_task_cpu" {
  description = "CPU (em unidades vCPU) da task Dynatrace"
  type        = number
  default     = 512
}

variable "dynatrace_task_memory" {
  description = "Memória (MB) da task Dynatrace"
  type        = number
  default     = 1024
}

variable "dynatrace_container_port" {
  description = "Porta exposta pelo container Dynatrace"
  type        = number
  default     = 8080
}

variable "dynatrace_health_check_path" {
  description = "Path de health-check do serviço Dynatrace"
  type        = string
  default     = "/actuator/health"
}

variable "dynatrace_oneagent_image" {
  description = "Imagem do Dynatrace OneAgent sidecar"
  type        = string
  default     = "public.ecr.aws/dynatrace/oneagent:latest"
}

variable "dynatrace_api_url" {
  description = "URL do cluster Dynatrace"
  type        = string
  default     = null
}

variable "dynatrace_tenant_id" {
  description = "Tenant ID do Dynatrace"
  type        = string
  default     = null
}

variable "dynatrace_api_token_secret_arn" {
  description = "ARN do secret contendo o token da API Dynatrace"
  type        = string
  default     = null
}

variable "container_image" {
  description = "Imagem do container (ex: <account>.dkr.ecr.<region>.amazonaws.com/repo:tag)"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023"
}

variable "native_container_image" {
  description = "Imagem do container nativo"
  type        = string
  default     = null
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 8080
}

variable "native_container_port" {
  description = "Porta exposta pelo container nativo"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path de health-check do ALB"
  type        = string
  default     = "/actuator/health"
}

variable "native_health_check_path" {
  description = "Path de health-check do serviço nativo"
  type        = string
  default     = "/actuator/health"
}

variable "jvm_tool_options" {
  description = "Valor padrão para JAVA_TOOL_OPTIONS dentro do container"
  type        = string
  default     = "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
}

variable "native_dd_service_name" {
  description = "Valor do DD_SERVICE para o serviço nativo"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Dias de retenção para logs no CloudWatch"
  type        = number
  default     = 14
}

variable "github_owner" {
  description = "Organizacao ou usuario do GitHub que hospeda o repositorio"
  type        = string
}

variable "github_repository" {
  description = "Nome do repositorio no GitHub"
  type        = string
}

variable "github_branch" {
  description = "Branch principal que podera assumir a role de deploy"
  type        = string
  default     = "main"
}

variable "github_oidc_provider_arn" {
  description = "ARN de um provider OIDC existente para GitHub (opcional)"
  type        = string
  default     = null
}

variable "enable_datadog_agent" {
  description = "Habilita o sidecar do Datadog na task ECS"
  type        = bool
  default     = false
}

variable "datadog_api_key_secret_arn" {
  description = "ARN do secret no Secrets Manager contendo a chave do Datadog"
  type        = string
  default     = null
}

variable "datadog_api_key_value" {
  description = "Valor da chave Datadog usado para criar um secret gerenciado (opcional e sensível)"
  type        = string
  default     = null
  sensitive   = true
}

variable "datadog_site" {
  description = "Site Datadog a ser utilizado"
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_agent_image" {
  description = "Imagem do Datadog Agent"
  type        = string
  default     = "public.ecr.aws/datadog/agent:latest"
}

variable "datadog_apm_enabled" {
  description = "Habilita coleta de traces no Datadog Agent"
  type        = bool
  default     = false
}

variable "datadog_java_agent_path" {
  description = "Caminho completo do dd-java-agent.jar dentro do container da aplicacao"
  type        = string
  default     = "/opt/datadog/dd-java-agent.jar"
}

variable "datadog_logs_enabled" {
  description = "Habilita forward de logs pelo Datadog Agent"
  type        = bool
  default     = true
}

variable "datadog_tags" {
  description = "Tags adicionais para o Datadog (formato chave:valor separado por virgula)"
  type        = string
  default     = null
}
