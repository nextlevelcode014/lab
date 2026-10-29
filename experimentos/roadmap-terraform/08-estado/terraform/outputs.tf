output "bucket" {
  value = aws_s3_bucket.app.bucket
}

output "usuario" {
  value = aws_iam_user.app.name
}
