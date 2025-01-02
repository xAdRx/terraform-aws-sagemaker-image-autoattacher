variable "name" {
  description = "Name of the stack"
  type        = string
  default     = "example-name"
}

variable "sagemaker_domain_id"{
  description = "ID of SageMaker domain. Used as a target of auto attacher"
  type        = string
}

variable "sagemaker_role_arn" {
  description = "ARN of SageMaker role. Used for attaching the image properly"
  type        = string
}

variable "image_type" {
  description = "Whether it should handle JupyterLab or CodeEditor images"
  default = "jupyter"

   validation {
    condition     = var.image_type == "jupyter" || var.image_type == "code_editor"
    error_message = "image_type must be either 'jupyter' or 'code_editor'."
  }
}

variable "tags" {
  description = "Map of tags"
  type        = map(string)
}