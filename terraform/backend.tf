terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "rodrigosantiag-org"

    workspaces {
      name = "simple-api"
    }
  }
}
