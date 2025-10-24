output "ecr_repository_url" {
  description = "URI completo do repositório ECR"
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS"
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "Família da task definition usada pelo serviço"
  value       = aws_ecs_task_definition.this.family
}

output "load_balancer_dns" {
  description = "Endpoint HTTP público do ALB"
  value       = aws_lb.this.dns_name
}
