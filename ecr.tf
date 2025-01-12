resource "aws_ecr_repository" "this" {
  name                 = "${var.name}"
  image_tag_mutability = var.ecr_immutable ? "IMMUTABLE" : "MUTABLE"

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = var.ecr_lifecycle_policy != null ? var.ecr_lifecycle_policy : local.default_lifecycle_policy
}
