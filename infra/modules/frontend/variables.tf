variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the API load balancer (origin for /api/*)."
  type        = string
}

variable "origin_verify_header_name" {
  description = "Custom header CloudFront adds to ALB origin requests."
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_verify_header_value" {
  description = "Shared secret value of the origin-verify header."
  type        = string
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = NA + EU edges, cheapest)."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200 or PriceClass_All."
  }
}

variable "force_destroy" {
  description = "Allow destroying the bucket while it still has objects (demo convenience)."
  type        = bool
  default     = false
}
