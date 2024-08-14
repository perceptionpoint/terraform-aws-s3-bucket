variable "bucket_name" { type = string }
variable "tags" { type = map(string) }
variable "encrypt_bucket" {
  default = true
  type = bool
}
variable "bucket_policy_document" {
    type = string
    default = null
}
variable "bucket_object_ownership_rule" {
  default = null
  type = string
}
variable "bucket_website_configuration" {
  default = null
  type = object({
    index_document_suffix = string
    error_document_key = string
  })
}

variable cors_rules {
    default = null
    type = list(object({
      allowed_headers = list(string)
      allowed_methods = list(string)
      allowed_origins = list(string)
      max_age_seconds = optional(string)
    }))
  }

variable "publicly_readable_to_anyone_in_the_internet" {
  type = bool
  default = false # this variable is dangerous!
                  # set true with caution
}

variable "bucket_logging" {
  type = object({
    target_bucket = string
    target_prefix = optional(string, "")
  })
  default = null
}

variable "lifecycle_rules" {
  default = null
  type = list(object({
    id = optional(string)
    prefix = optional(string)
    expiration = optional(string)
    enabled = optional(bool, true)
    transition = optional(object({
        days = string
        storage_class = string
    }))
  }))
}

variable "access_control_policy" {
  default = null
  type = object({
    owner = string
    grants = list(object({
      permission = string
      type = optional(string, "Group")
      id = optional(string)
      uri = optional(string)
    }))
  })
}
