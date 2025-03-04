terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}


# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Create a web server
# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "app" {
  image    = "ubuntu-20-04-x64"
  name     = "elixir-api"
  region   = "nyc2"
  size     = "s-1vcpu-1gb"
  ssh_keys = [var.ssh_key_id]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = var.private_key
    host        = self.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo docker login ghcr.io -u ${var.github_username} -p ${var.github_token}",
      "sudo docker pull ghcr.io/rodrigosantiag/simple_api:latest",
      "sudo docker run -e SECRET_KEY_BASE=${var.secret_key_base} -d --name simple_api -p 4000:4000 ghcr.io/rodrigosantiag/simple_api:latest"
    ]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.app.ipv4_address
}