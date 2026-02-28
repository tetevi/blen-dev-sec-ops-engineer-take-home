locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Networking Module

module "networking" {
  source = "./modules/networking"

  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  environment           = var.environment
  project_name          = var.project_name
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  isolated_subnet_cidrs = var.isolated_subnet_cidrs
}

# Security Groups

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.networking.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = module.networking.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = module.networking.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Module

module "alb" {
  source = "./modules/alb"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = aws_security_group.alb.id
  ecs_security_group_id = aws_security_group.ecs.id
  certificate_arn       = var.certificate_arn
  container_port        = var.container_port
  health_check_path     = var.health_check_path
}

# Database Module

module "database" {
  source = "./modules/database"

  environment           = var.environment
  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  isolated_subnet_ids   = module.networking.isolated_subnet_ids
  db_security_group_id  = aws_security_group.rds.id
  ecs_security_group_id = aws_security_group.ecs.id
  db_username           = var.db_username
  db_password           = var.db_password
  db_name               = var.db_name
}

# ECS Module

module "ecs" {
  source = "./modules/ecs"

  environment                = var.environment
  project_name               = var.project_name
  aws_region                 = var.aws_region
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  ecs_security_group_id      = aws_security_group.ecs.id
  alb_security_group_id      = aws_security_group.alb.id
  rds_security_group_id      = aws_security_group.rds.id
  target_group_arn           = module.alb.target_group_arn
  container_image            = var.container_image
  container_port             = var.container_port
  task_cpu                   = var.ecs_task_cpu
  task_memory                = var.ecs_task_memory
  desired_count              = var.ecs_desired_count
  secrets_manager_secret_arn = module.database.secrets_manager_secret_arn
  db_name                    = var.db_name
}
