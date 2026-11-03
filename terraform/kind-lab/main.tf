terraform {
  required_providers {
    kind = {
      source  = "elioseverojunior/kind"
      version = "0.0.4"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "lab" {
  name = "terraform-lab"
}
