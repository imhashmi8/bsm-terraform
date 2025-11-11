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
  image              = "${module.ecr.repository_url}:latest"

  # ✅ Enable HTTPS on ALB (ap-south-1 cert for API hostname)
  alb_certificate_arn = "arn:aws:acm:ap-south-1:877634772120:certificate/07c88d89-531d-4437-b3ca-8e553ca9aefc"
  health_check_path   = "/actuator/health"

  tags = var.tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "bsm-prod-api"
  tags   = var.tags
}

module "rds" {
  source             = "../../modules/rds_postgres"
  name               = "bsm-prod"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_sg_ids     = [module.ecs.service_sg_id]

  engine_version        = "15.13"
  instance_class        = "db.t4g.large" # 2 vCPU, 8 GiB
  allocated_storage     = 20
  max_allocated_storage = 200

  multi_az             = true
  backup_retention     = 7
  deletion_protection  = true
  skip_final_snapshot  = false
  final_snapshot_identifier = "bsm-prod-final-${formatdate("DD-MM-YYYY", timestamp())}"
  performance_insights = true
  db_name              = "bsmproddb"
  tags                 = var.tags
}

# ---------------- Frontend: S3 + CloudFront (PROD) ----------------
module "frontend" {
  source              = "../../modules/frontend_static"
  name                = "bsm-prod"

  # S3 buckets (must be globally unique)
  site_bucket_name    = "bsm-prod-frontend"
  uploads_bucket_name = "bsm-prod-uploads" # or "" to skip uploads origin

  # ✅ CloudFront origin uses API hostname (matches ALB cert)
  alb_domain_name  = "api.biharsportsmahasangram.in"
  api_path_pattern = "/api/*"

  # ✅ Custom domains on CloudFront (us-east-1 cert)
  aliases             = ["biharsportsmahasangram.in", "www.biharsportsmahasangram.in"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:877634772120:certificate/55cd2353-4498-4bb3-b831-82e7f113fcfa"

  price_class = "PriceClass_100"
  tags        = var.tags
}

# ---------------- Route 53 Alias for PROD ----------------
data "aws_route53_zone" "main" {
  name         = "biharsportsmahasangram.in."
  private_zone = false
}

# ✅ API hostname → ALB (used as CloudFront origin)
resource "aws_route53_record" "api_prod" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.biharsportsmahasangram.in"
  type    = "A"
  alias {
    name                   = module.ecs.alb_dns_name
    zone_id                = module.ecs.alb_zone_id
    evaluate_target_health = false
  }
}

# ✅ Root apex → CloudFront
resource "aws_route53_record" "frontend_root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "biharsportsmahasangram.in"
  type    = "A"
  alias {
    name                   = module.frontend.distribution_domain_name
    zone_id                = module.frontend.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# ✅ www → CloudFront
resource "aws_route53_record" "frontend_www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.biharsportsmahasangram.in"
  type    = "A"
  alias {
    name                   = module.frontend.distribution_domain_name
    zone_id                = module.frontend.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
