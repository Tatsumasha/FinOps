variable "project" {
  description = "The ID of the project in which the resource belongs. If it is not provided, the provider project is used."
  type        = string
  default     = null
}

variable "region" {
  description = "The region of the project in which the resource belongs"
  type        = string
  default     = null
}