variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "repository_name" {
  description = "Repository name suffix, e.g. \"api\"."
  type        = string
}

variable "keep_images" {
  description = "Number of images to retain."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow destroying the repository even if it still contains images (demo convenience)."
  type        = bool
  default     = false
}
