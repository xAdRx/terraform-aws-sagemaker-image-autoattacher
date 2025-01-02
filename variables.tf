variable "name" {
  description = "Name of the stack"
  type        = string
  default     = "example-name"
}

variable "tags" {
  description = "Tags"
  type        = map(string)
}

variable "domain_id"{

}

variable "sagemaker_role_arn" {
  
}

variable "image_type" {
  description = "Whether it should handle JupyterLab or CodeEditor images"
  default = "jupyter"

   validation {
    condition     = var.image_type == "jupyter" || var.image_type == "code_editor"
    error_message = "image_type must be either 'jupyter' or 'code_editor'."
  }
}