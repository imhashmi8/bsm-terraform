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
  container_port     = 8080
  image              = "${module.ecr.repository_url}:latest"

  # ✅ Enable HTTPS on ALB (ap-south-1 cert)
  alb_certificate_arn = "arn:aws:acm:ap-south-1:877634772120:certificate/bc95b265-bc74-490b-ae1a-36d19b3c8ac4"
  health_check_path = "/api/test/health"

  tags = var.tags
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
  instance_class        = "db.t4g.small"
  allocated_storage     = 20
  max_allocated_storage = 100

  multi_az             = false
  backup_retention     = 3
  deletion_protection  = false
  skip_final_snapshot  = true
  performance_insights = false
  db_name              = "bsmstgdb"
  tags                 = var.tags
}

# ---------------- S3 + CloudFront (staging) ----------------
module "frontend" {
  source = "../../modules/frontend_static"
  name   = "bsm-stg"

  site_bucket_name    = "bsm-stg-frontend"
  uploads_bucket_name = "bsm-stg-uploads"

  # ✅ CF will talk to ALB using your API hostname over HTTPS
  alb_domain_name  = "api.dev.biharsportsmahasangram.in"
  api_path_pattern = "/api/*"

  # ✅ CF custom domain + us-east-1 certificate
  aliases             = ["dev.biharsportsmahasangram.in"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:877634772120:certificate/615fd047-95fa-4712-a5b0-6fe6d33fe915"

  tags = var.tags
}

# ---------------- Route 53 DNS Records (staging) ----------------

# Use your existing public hosted zone
data "aws_route53_zone" "main" {
  name         = "biharsportsmahasangram.in."
  private_zone = false
}

# ✅ API hostname -> ALB (so CF origin host matches ALB cert)
resource "aws_route53_record" "api_stg" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.dev.biharsportsmahasangram.in"
  type    = "A"
  alias {
    name                   = module.ecs.alb_dns_name
    zone_id                = module.ecs.alb_zone_id
    evaluate_target_health = false
  }
}

# ✅ Frontend hostname -> CloudFront
resource "aws_route53_record" "frontend_stg" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.biharsportsmahasangram.in"
  type    = "A"
  alias {
    name                   = module.frontend.distribution_domain_name
    zone_id                = module.frontend.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
