provider "aws" {
  region = var.region
  access_key = var.access_key_id
  secret_key = var.secret_access_key

  endpoints {
    iam = "https://iam.${var.csp_domain}"

    ec2  = "https://ec2.${var.region}.${var.csp_domain}"
    ecr  = "https://ecr.${var.region}.${var.csp_domain}"
    eks  = "https://eks.${var.region}.${var.csp_domain}"
    kms  = "https://kms.${var.region}.${var.csp_domain}"
    logs = "https://monitoring.${var.region}.${var.csp_domain}"
    rds  = "https://rds.${var.region}.${var.csp_domain}"
    s3   = "https://s3.${var.region}.${var.csp_domain}"
    sts  = "https://sts.${var.region}.${var.csp_domain}"
  }
}
