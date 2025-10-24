project_name      = "ecs-demo"
environment       = "dev"
region            = "us-east-1"
desired_count     = 1
container_image   = "public.ecr.aws/amazonlinux/amazonlinux:2023"
jvm_tool_options  = "-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"
