# Usuário só do Coolify: é a chave dele que vai para o painel. Se vazar da
# VPS, alcança só este bucket (a policy) e nunca passa do lab-boundary.
resource "aws_iam_user" "coolify" {
  name                 = "lab-coolify-backup"
  path                 = "/lab/"
  permissions_boundary = local.boundary
}

resource "aws_iam_user_policy" "coolify" {
  name = "backup"
  user = aws_iam_user.coolify.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
        Resource = aws_s3_bucket.backup.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = "${aws_s3_bucket.backup.arn}/*"
      },
    ]
  })
}

# O segredo fica no state (local, fora do git): aceitável no lab.
resource "aws_iam_access_key" "coolify" {
  user = aws_iam_user.coolify.name
}
