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

variable "task_cpu" {
  description = "CPU (em unidades vCPU) para a task Fargate"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memória (MB) para a task Fargate"
  type        = number
  default     = 1024
}

variable "container_image" {
  description = "Imagem do container (ex: <account>.dkr.ecr.<region>.amazonaws.com/repo:tag)"
  type        = string
  default     = "public.ecr.aws/amazonlinux/amazonlinux:2023"
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Path de health-check do ALB"
  type        = string
  default     = "/actuator/health"
}

variable "jvm_tool_options" {
  description = "Valor padrão para JAVA_TOOL_OPTIONS dentro do container"
  type        = string
  default     = "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
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
