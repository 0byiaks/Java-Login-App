# Application VPC Module (3-tier architecture)
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = var.vpc_cidr
  public_subnet_az1_cidr = var.public_subnet_az1_cidr
  public_subnet_az2_cidr = var.public_subnet_az2_cidr
  private_subnet_app_az1_cidr = var.private_subnet_app_az1_cidr
  private_subnet_app_az2_cidr = var.private_subnet_app_az2_cidr
  private_subnet_db_az1_cidr = var.private_subnet_db_az1_cidr
  private_subnet_db_az2_cidr = var.private_subnet_db_az2_cidr
  project_name = var.project_name
  environment = var.environment
  bastion_subnet_cidr = var.bastion_public_subnet_cidr
   # Will be updated when NLB is created
}

# Bastion VPC Module (Admin Access)
module "bastion_vpc" {
  source = "./modules/bastion-vpc"

  vpc_cidr            = var.bastion_vpc_cidr
  public_subnet_cidr  = var.bastion_public_subnet_cidr
  project_name       = var.project_name
  environment        = var.environment
  admin_ip_cidr      = var.admin_ip_cidr
  app_vpc_private_cidrs = [
    var.private_subnet_app_az1_cidr,
    var.private_subnet_app_az2_cidr,
    var.private_subnet_db_az1_cidr,
    var.private_subnet_db_az2_cidr
  ]
}

# Transit Gateway Module
module "transit_gateway" {
  source = "./modules/transit-gateway"

  environment              = var.environment
  project_name            = var.project_name
  app_vpc_id              = module.vpc.vpc_id
  app_vpc_subnet_ids      = module.vpc.public_subnet_ids
  app_vpc_route_table_ids = [
    module.vpc.public_route_table_id,
    module.vpc.private_route_table_id
  ]
  app_vpc_cidr            = var.vpc_cidr
  bastion_vpc_id          = module.bastion_vpc.bastion_vpc_id
  bastion_vpc_subnet_id   = module.bastion_vpc.bastion_public_subnet_id
  bastion_vpc_route_table_id = module.bastion_vpc.bastion_public_route_table_id
  bastion_vpc_cidr        = var.bastion_vpc_cidr
}

# Private NLB for Tomcat
module "nlb" {
  source = "./modules/nlb"

  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids  # Private app subnets in AZ 1a and 1b
}

# Tomcat Auto Scaling Group
module "tomcat_asg" {
  source = "./modules/tomcat-asg"

  environment              = var.environment
  project_name             = var.project_name
  tomcat_golden_ami_id     = module.tomcat_golden_ami.tomcat_golden_ami_id
  tomcat_security_group_id = module.vpc.tomcat_security_group_id
  iam_instance_profile_name = module.ami.iam_instance_profile_name
  private_subnet_ids       = module.vpc.private_app_subnet_ids  # Private subnets AZ 1a and 1b
  target_group_arn         = module.nlb.tomcat_target_group_arn
  instance_type            = var.tomcat_instance_type
  desired_capacity         = 2
  min_size                 = 1
  max_size                 = 4
  s3_bucket                = var.s3_bucket

  depends_on = [module.tomcat_golden_ami, module.nlb]
}











# Global Base AMI Builder Module
module "ami" {
  source = "./modules/ami"

  environment        = var.environment
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  ssh_allowed_cidr   = var.ssh_allowed_cidr
  instance_type      = var.ami_builder_instance_type
  aws_region         = var.aws_region
}

# Nginx Golden AMI Builder Module
module "nginx_golden_ami" {
  source = "./modules/nginx-golden-ami"

  environment              = var.environment
  project_name            = var.project_name
  global_base_ami_id      = module.ami.ami_id
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  vpc_cidr                = var.vpc_cidr
  ssh_allowed_cidr        = var.ssh_allowed_cidr
  instance_type           = var.ami_builder_instance_type
  aws_region              = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# Tomcat Golden AMI Builder Module
module "tomcat_golden_ami" {
  source = "./modules/tomcat-golden-ami"

  environment              = var.environment
  project_name            = var.project_name
  global_base_ami_id      = module.ami.ami_id
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  vpc_cidr                = var.vpc_cidr
  ssh_allowed_cidr        = var.ssh_allowed_cidr
  instance_type           = var.ami_builder_instance_type
  aws_region              = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# Maven Golden AMI Builder Module
module "maven_golden_ami" {
  source = "./modules/maven-golden-ami"

  environment              = var.environment
  project_name            = var.project_name
  global_base_ami_id      = module.ami.ami_id
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_ids[0]
  vpc_cidr                = var.vpc_cidr
  ssh_allowed_cidr        = var.ssh_allowed_cidr
  instance_type           = var.ami_builder_instance_type
  aws_region              = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# RDS MySQL Database Module
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  project_name          = var.project_name
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  db_security_group_id  = module.vpc.db_security_group_id
  availability_zone      = null  # Will use first AZ (us-east-1a) by default
}

# Bastion Host Module
module "bastion_host" {
  source = "./modules/bastion-host"

  environment          = var.environment
  project_name         = var.project_name
  public_subnet_id     = module.bastion_vpc.bastion_public_subnet_id
  security_group_id    = module.bastion_vpc.bastion_sg_id
  instance_type        = var.ami_builder_instance_type
  use_global_base_ami  = false  # Use Amazon Linux 2 for simplicity
  global_base_ami_id   = ""     # Not used when use_global_base_ami is false
  rds_endpoint         = module.rds.db_instance_endpoint
  rds_secret_arn       = module.rds.master_user_secret_arn
  aws_region           = var.aws_region
  s3_bucket_uri        = "s3://dev-shop-app-webfiles/schema.sql"
  rds_dependency       = module.rds.db_instance_id  # Ensure RDS and secret are created first

  depends_on = [module.rds]
}