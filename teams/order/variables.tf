variable "attach_tls_only_policy" {
  description = "Attach TLS Only Policy, Default True"
  type        = bool
  default     = true
}


variable "attach_tls_12_required_policy" {
  description = "Attach TLS 1.2 Policy, Default True"
  type        = bool
  default     = true
}

variable "buckets" {
  type = list(object({
    name = string
    type = string
  }))

  validation {
    condition     = length(var.buckets) > 1
    error_message = "At least one bucket is required"
  }
}
