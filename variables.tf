variable "access_key_id" {
  type      = string
  sensitive = true
}

variable "secret_access_key" {
  type      = string
  sensitive = true
}

variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "instance_count" {
  type    = number
  default = 4
}

variable "region" {
  type = string
}

variable "csp" {
  type        = string
  description = "Cloud Service Provider: SPC or AWS"
}

variable "csp_domain" {
  type        = string
  description = "Root domain name of the cloud API endpoint"
}

variable "zones" {
  description = "for multi availability zone deployment"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "private_subnet_cidrs" {
  default     =  [ "10.0.2.0/24" ]
  description = "CIDR blocks for private subnets"
}

variable "public_subnet_cidr" {
  default     = "10.0.1.0/24"
  description = "CIDR blocks for public subnets"
}
