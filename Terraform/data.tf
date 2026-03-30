data "aws_secretsmanager_secret" "maven_build" {
  count = var.maven_build_app_secret_name != "" ? 1 : 0
  name  = var.maven_build_app_secret_name
}
