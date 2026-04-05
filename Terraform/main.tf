# Application VPC Module (3-tier architecture)
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr                    = var.vpc_cidr
  public_subnet_az1_cidr      = var.public_subnet_az1_cidr
  public_subnet_az2_cidr      = var.public_subnet_az2_cidr
  private_subnet_app_az1_cidr = var.private_subnet_app_az1_cidr
  private_subnet_app_az2_cidr = var.private_subnet_app_az2_cidr
  private_subnet_db_az1_cidr  = var.private_subnet_db_az1_cidr
  private_subnet_db_az2_cidr  = var.private_subnet_db_az2_cidr
  project_name                = var.project_name
  environment                 = var.environment
  bastion_subnet_cidr         = var.bastion_public_subnet_cidr
  # Will be updated when NLB is created
}

# Bastion VPC Module (Admin Access)
module "bastion_vpc" {
  source = "./modules/bastion-vpc"

  vpc_cidr           = var.bastion_vpc_cidr
  public_subnet_cidr = var.bastion_public_subnet_cidr
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

  environment        = var.environment
  project_name       = var.project_name
  app_vpc_id         = module.vpc.vpc_id
  app_vpc_subnet_ids = module.vpc.public_subnet_ids
  app_vpc_route_table_ids = [
    module.vpc.public_route_table_id,
    module.vpc.private_route_table_id
  ]
  app_vpc_cidr               = var.vpc_cidr
  bastion_vpc_id             = module.bastion_vpc.bastion_vpc_id
  bastion_vpc_subnet_id      = module.bastion_vpc.bastion_public_subnet_id
  bastion_vpc_route_table_id = module.bastion_vpc.bastion_public_route_table_id
  bastion_vpc_cidr           = var.bastion_vpc_cidr
}

# Private NLB for Tomcat
module "nlb" {
  source = "./modules/nlb"

  environment        = var.environment
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_app_subnet_ids # Private app subnets in AZ 1a and 1b
}

# Public NLB for Nginx (internet-facing)
module "public_nlb" {
  source = "./modules/public-nlb"

  environment       = var.environment
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# Tomcat Auto Scaling Group
module "tomcat_asg" {
  source = "./modules/tomcat-asg"

  environment                   = var.environment
  project_name                  = var.project_name
  tomcat_golden_ami_id          = module.tomcat_golden_ami.tomcat_golden_ami_id
  tomcat_security_group_id      = module.vpc.tomcat_security_group_id
  iam_instance_profile_name     = module.ami.iam_instance_profile_name
  private_subnet_ids            = module.vpc.private_app_subnet_ids # Private subnets AZ 1a and 1b
  target_group_arn              = module.nlb.tomcat_target_group_arn
  instance_type                 = var.tomcat_instance_type
  desired_capacity              = 2
  min_size                      = 1
  max_size                      = 4
  aws_region                    = var.aws_region
  app_secrets_manager_secret_id = var.maven_build_app_secret_name
  jfrog_war_url                 = var.tomcat_jfrog_war_url
  rds_secret_arn                = module.rds.master_user_secret_arn

  depends_on = [module.tomcat_golden_ami, module.nlb, module.rds]
}

# Nginx Auto Scaling Group (private subnets, fronted by public NLB)
module "nginx_asg" {
  source = "./modules/nginx-asg"

  environment               = var.environment
  project_name              = var.project_name
  nginx_golden_ami_id       = module.nginx_golden_ami.nginx_golden_ami_id
  nginx_security_group_id   = module.vpc.nginx_security_group_id
  iam_instance_profile_name = module.ami.iam_instance_profile_name
  private_subnet_ids        = module.vpc.public_subnet_ids
  target_group_arn          = module.public_nlb.nginx_target_group_arn
  private_nlb_dns_name      = module.nlb.nlb_dns_name
  instance_type             = var.nginx_instance_type
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 4

  depends_on = [module.nginx_golden_ami, module.public_nlb, module.nlb]
}











# Global Base AMI Builder Module
module "ami" {
  source = "./modules/ami"

  environment      = var.environment
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  ssh_allowed_cidr = var.ssh_allowed_cidr
  instance_type    = var.ami_builder_instance_type
  aws_region       = var.aws_region

  secretsmanager_secret_arns = compact(concat(
    length(data.aws_secretsmanager_secret.maven_build) > 0 ? [data.aws_secretsmanager_secret.maven_build[0].arn] : [],
    [module.rds.master_user_secret_arn]
  ))
}

# Nginx Golden AMI Builder Module
module "nginx_golden_ami" {
  source = "./modules/nginx-golden-ami"

  environment               = var.environment
  project_name              = var.project_name
  global_base_ami_id        = module.ami.ami_id
  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnet_ids[0]
  vpc_cidr                  = var.vpc_cidr
  ssh_allowed_cidr          = var.ssh_allowed_cidr
  instance_type             = var.ami_builder_instance_type
  aws_region                = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# Tomcat Golden AMI Builder Module
module "tomcat_golden_ami" {
  source = "./modules/tomcat-golden-ami"

  environment               = var.environment
  project_name              = var.project_name
  global_base_ami_id        = module.ami.ami_id
  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnet_ids[0]
  vpc_cidr                  = var.vpc_cidr
  ssh_allowed_cidr          = var.ssh_allowed_cidr
  instance_type             = var.ami_builder_instance_type
  aws_region                = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# Maven Golden AMI Builder Module
module "maven_golden_ami" {
  source = "./modules/maven-golden-ami"

  environment               = var.environment
  project_name              = var.project_name
  global_base_ami_id        = module.ami.ami_id
  vpc_id                    = module.vpc.vpc_id
  public_subnet_id          = module.vpc.public_subnet_ids[0]
  vpc_cidr                  = var.vpc_cidr
  ssh_allowed_cidr          = var.ssh_allowed_cidr
  instance_type             = var.ami_builder_instance_type
  aws_region                = var.aws_region
  iam_instance_profile_name = module.ami.iam_instance_profile_name
}

# Long-lived Maven build host: clones repo, loads JFrog/GitHub creds from Secrets Manager, mvn clean deploy
module "maven_build_instance" {
  source = "./modules/maven-build-instance"

  environment                   = var.environment
  project_name                  = var.project_name
  vpc_id                        = module.vpc.vpc_id
  subnet_id                     = module.vpc.private_app_subnet_ids[0]
  maven_golden_ami_id           = module.maven_golden_ami.maven_golden_ami_id
  iam_instance_profile_name     = module.ami.iam_instance_profile_name
  bastion_subnet_cidr           = var.bastion_public_subnet_cidr
  instance_type                 = var.maven_build_instance_type
  git_repo_url                  = var.maven_build_git_repo_url
  aws_region                    = var.aws_region
  app_secrets_manager_secret_id = var.maven_build_app_secret_name
  ec2_key_name                  = var.maven_build_ec2_key_name

  depends_on = [module.maven_golden_ami]
}

# RDS MySQL Database Module
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  project_name          = var.project_name
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  db_security_group_id  = module.vpc.db_security_group_id
  availability_zone     = null # Will use first AZ (us-east-1a) by default
}

# Bastion Host Module
module "bastion_host" {
  source = "./modules/bastion-host"

  environment         = var.environment
  project_name        = var.project_name
  public_subnet_id    = module.bastion_vpc.bastion_public_subnet_id
  security_group_id   = module.bastion_vpc.bastion_sg_id
  instance_type       = var.ami_builder_instance_type
  use_global_base_ami = false # Use Amazon Linux 2 for simplicity
  global_base_ami_id  = ""    # Not used when use_global_base_ami is false
  rds_endpoint        = module.rds.db_instance_endpoint
  rds_secret_arn      = module.rds.master_user_secret_arn
  aws_region          = var.aws_region
  s3_bucket_uri       = "s3://dev-shop-app-webfiles/schema.sql"
  rds_dependency      = module.rds.db_instance_id # Ensure RDS and secret are created first

  depends_on = [module.rds]
}