variable "db_username" {
  description = "Nom de l'utilisateur admin PostgreSQL"
  type        = string
}

/*
variable "db_password" {
  description = "Mot de passe admin PostgreSQL"
  type        = string
  sensitive   = true
}
*/

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}
