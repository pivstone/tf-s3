variable "team_name" {
  description = "Team Name"
  default     = null
  nullable    = true
  type        = string
}

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

variable "name" {
  description = "S3 Bucket Short Name"
  type        = string
  nullable    = false
  validation {
    condition     = length(var.name) > 3
    error_message = "The Bucket Name must have at least 4 character"
  }
  validation {
    condition     = length(var.name) < 33
    error_message = "The Bucket Name must not exceed 32 character"
  }

  validation {
    condition     = can(regex("^[a-z0-9\\-]+$", var.name))
    error_message = "The Bucket Name only allow lower case and numbers"
  }
}

variable "type" {
  description = "the type of bucket. Allowed Value: public or private"
  nullable    = false
  type        = string

  validation {
    condition     = contains(["public", "private"], var.type)
    error_message = "Only the value public or private is allow"
  }
}

variable "role_id" {
  description = "IAM Role ID"
  nullable    = false
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "Bucket Tags"
  default     = {}
}