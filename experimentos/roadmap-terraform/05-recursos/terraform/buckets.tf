variable "nomes" {
  type    = list(string)
  default = ["b", "c"]
}

resource "aws_s3_bucket" "c" {
  for_each      = toset(var.nomes)
  bucket_prefix = "lab-roadmap-05-${each.key}-v3-"
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}

resource "aws_s3_bucket" "us" {
  region        = "us-east-1"
  bucket_prefix = "lab-roadmap-05-us-"
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
  }
}
