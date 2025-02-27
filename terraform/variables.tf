variable "ssh_key_id" {
  description = "The SSH key ID to use for the droplet"
  type        = string
}

variable "github_username" {
  description = "The GitHub username"
  type        = string
}

variable "github_token" {
  description = "The GitHub personal access token"
  type        = string
}

variable "do_token" {
  description = "The digital ocean API token"
  type        = string
}

variable "secret_key_base" {
  description = "The secret key base for the Phoenix app"
  type        = string
}

variable "private_key" {
  description = "The private key to use for the droplet"
  type        = string
}