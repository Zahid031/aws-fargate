variable "enabled" {
  description = "Whether to create VPC endpoints"
  type        = bool
  default     = true
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnets where interface endpoints will be placed"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Private route tables for S3 gateway endpoint association"
  type        = list(string)
}

variable "endpoint_sg_id" {
  description = "Security group to attach to interface endpoints"
  type        = string
}
