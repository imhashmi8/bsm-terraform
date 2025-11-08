module "vpc" {
  source               = "../../modules/vpc"
  name                 = "bsm-stg"
  cidr_block           = "10.20.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  tags                 = var.tags
}

module "ecs" {
  source             = "../../modules/ecs_alb_service"
  name               = "bsm-stg"
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_count      = 2
  container_port     = 80
  image              = "${module.ecr.repository_url}:latest"
  tags               = var.tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "bsm-stg-api"
  tags   = var.tags
}

module "rds" {
  source             = "../../modules/rds_postgres"
  name               = "bsm-stg"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_sg_ids     = [module.ecs.service_sg_id]

  engine_version        = "15.13"
  instance_class        = "db.t4g.small" # 2 vCPU, 2 GiB
  allocated_storage     = 20
  max_allocated_storage = 100

  multi_az             = false
  backup_retention     = 3
  deletion_protection  = false
  performance_insights = false
  db_name              = "bsmstgdb"
  tags                 = var.tags
}
