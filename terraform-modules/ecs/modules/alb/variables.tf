variable "project_name"      { type = string }
variable "environment"       { type = string }
variable "vpc_id"            { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "sg_alb_id"         { type = string }
variable "app_port"          { type = number }
variable "health_check_path" { type = string }
