#!/usr/bin/env bash
# Cria, uma vez por conta, o usuário IAM do lab (docs/nuvem.md). Rode no AWS
# CloudShell logado como admin: criar usuário e policy exige IAM de admin, que
# o próprio lab não tem, de propósito. Pode rodar de novo: atualiza as policies.
#
# O que sai daqui:
#   - lab-boundary: teto de todo usuário que o Terraform do lab criar. Só
#     buckets lab-*. Mesmo que o Terraform escreva "Action": "*" num usuário,
#     o que vale é a interseção com este teto.
#   - lab-terraform: o usuário do Terraform do lab. Mexe em buckets lab-* e
#     cria usuários em /lab/, mas só se anexar o lab-boundary; sem isso ele
#     poderia criar um admin e usar a chave dele.
set -euo pipefail

conta=$(aws sts get-caller-identity --query Account --output text)
boundary="arn:aws:iam::${conta}:policy/lab/lab-boundary"

boundary_doc=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketsDoLab",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"],
      "Resource": "arn:aws:s3:::lab-*"
    },
    {
      "Sid": "ObjetosDoLab",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
      "Resource": "arn:aws:s3:::lab-*/*"
    }
  ]
}
EOF
)

terraform_doc=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketsDoLab",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::lab-*", "arn:aws:s3:::lab-*/*"]
    },
    {
      "Sid": "UsuariosDoLabSoComBoundary",
      "Effect": "Allow",
      "Action": [
        "iam:CreateUser", "iam:PutUserPermissionsBoundary",
        "iam:PutUserPolicy", "iam:DeleteUserPolicy",
        "iam:AttachUserPolicy", "iam:DetachUserPolicy"
      ],
      "Resource": "arn:aws:iam::${conta}:user/lab/*",
      "Condition": {"StringEquals": {"iam:PermissionsBoundary": "${boundary}"}}
    },
    {
      "Sid": "UsuariosDoLab",
      "Effect": "Allow",
      "Action": [
        "iam:GetUser", "iam:DeleteUser", "iam:TagUser", "iam:UntagUser", "iam:ListUserTags",
        "iam:GetUserPolicy", "iam:ListUserPolicies", "iam:ListAttachedUserPolicies", "iam:ListGroupsForUser",
        "iam:CreateAccessKey", "iam:DeleteAccessKey", "iam:UpdateAccessKey", "iam:ListAccessKeys",
        "iam:ListSSHPublicKeys", "iam:ListServiceSpecificCredentials", "iam:ListSigningCertificates",
        "iam:ListMFADevices", "iam:GetLoginProfile"
      ],
      "Resource": "arn:aws:iam::${conta}:user/lab/*"
    },
    {
      "Sid": "NuncaTirarOuMudarOTeto",
      "Effect": "Deny",
      "Action": [
        "iam:DeleteUserPermissionsBoundary",
        "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:SetDefaultPolicyVersion", "iam:DeletePolicy"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

if aws iam get-policy --policy-arn "$boundary" >/dev/null 2>&1; then
  # Uma policy gerenciada guarda até 5 versões: apaga as antigas antes.
  for v in $(aws iam list-policy-versions --policy-arn "$boundary" \
      --query 'Versions[?!IsDefaultVersion].VersionId' --output text); do
    aws iam delete-policy-version --policy-arn "$boundary" --version-id "$v"
  done
  aws iam create-policy-version --policy-arn "$boundary" \
    --policy-document "$boundary_doc" --set-as-default >/dev/null
  echo "lab-boundary atualizado"
else
  aws iam create-policy --path /lab/ --policy-name lab-boundary \
    --policy-document "$boundary_doc" --tags Key=env,Value=lab >/dev/null
  echo "lab-boundary criado"
fi

# Fora de /lab/ de propósito: as permissões dele valem para user/lab/*, e ele
# não pode alcançar a si mesmo (criar chave nova, se apagar).
if ! aws iam get-user --user-name lab-terraform >/dev/null 2>&1; then
  aws iam create-user --user-name lab-terraform --tags Key=env,Value=lab >/dev/null
  echo "lab-terraform criado"
fi
aws iam put-user-policy --user-name lab-terraform --policy-name lab-terraform \
  --policy-document "$terraform_doc"
echo "policy do lab-terraform aplicada"

if [ "$(aws iam list-access-keys --user-name lab-terraform --query 'length(AccessKeyMetadata)')" = 0 ]; then
  echo
  echo "Chave do lab-terraform (aparece só agora; vai para o 'aws configure --profile lab'):"
  aws iam create-access-key --user-name lab-terraform \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
fi
