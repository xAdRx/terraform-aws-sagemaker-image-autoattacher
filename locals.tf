locals{
    image_type = {
        "jupyter"     = "JupyterLab"
        "code_editor" = "CodeEditor"
    }
    default_lifecycle_policy = <<EOF
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