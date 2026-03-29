terraform {
  backend "s3" {
    bucket         = "cloudporject-terraform-remote-state"
    key            = "dev/java-login-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}