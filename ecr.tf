resource "aws_ecr_repository" "this" {
  name                 = "${var.name}"
  image_tag_mutability = "IMMUTABLE" #PARAMETER

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
#PARAMETER
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Image count higher than 100",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 100
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
