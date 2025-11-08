module "vpc" {
  source               = "../../modules/vpc"
  name                 = "bsm-prod"
  cidr_block           = "10.30.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.30.0.0/24", "10.30.1.0/24"]
  private_subnet_cidrs = ["10.30.10.0/24", "10.30.11.0/24"]
  tags                 = var.tags
}

module "ecs" {
  source             = "../../modules/ecs_alb_service"
  name               = "bsm-prod"
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  desired_count      = 3
  container_port     = 80
  image              = "${module.ecr_api.repository_url}:latest"
  tags               = var.tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "bsm-prod-api"
  tags   = var.tags
}

module "rds" {
  source               = "../../modules/rds_postgres"
  name                 = "bsm-prod"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  allowed_sg_ids       = [module.ecs.service_sg_id]

  engine_version       = "15.13"
  instance_class       = "db.t4g.large"      # 2 vCPU, 8 GiB
  allocated_storage    = 20
  max_allocated_storage= 200

  multi_az             = true
  backup_retention     = 7
  deletion_protection  = true
  performance_insights = true
  db_name              = "bsmproddb"
  tags                 = var.tags
}
