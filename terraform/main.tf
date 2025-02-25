terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Set the variable value in *.tfvars file
# or using -var="do_token=..." CLI option
variable "do_token" {}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Create a web server
# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "web" {
  image   = "ubuntu-20-04-x64"
  name    = "elixir-api"
  region  = "nyc2"
  size    = "s-1vcpu-1gb"

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y elixir erlang nginx",
      "sudo systemctl restart nginx"
    ]    
  }
}