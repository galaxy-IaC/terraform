provider "aws" {
  region = var.aws_region
}

# create random pet resource
resource "random_pet" "this" {
  length = 2
}