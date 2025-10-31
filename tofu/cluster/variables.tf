variable "name" {
  description = "Name of the cluster (optional). If not provided, a random name will be generated. Always prefixed with \"cluster-\"."
  type        = string
  default     = ""
}

variable "image_name" {
  description = "Name or regex for the image to use for the cluster nodes."
  type        = string
  default     = ""
}

variable "image_id" {
  description = "ID of the image to use for the cluster nodes (optional). If set, this takes precedence over image_name."
  type        = string
  default     = ""
}

variable "ssh_username" {
  description = "SSH username for connecting to the cluster nodes."
  type        = string
  default     = "ubuntu"
}

variable "control_plane_node" {
  description = "Control plane node to assign to the cluster."
  type = object({
    flavor = string
  })
  default = {
    flavor = "gp1.medium"
  }
}

variable "worker_nodes" {
  description = "Worker nodes to assign to the cluster."
  type = object({
    count  = number
    flavor = string
  })
  default = {
    count  = 3
    flavor = "m1.extra_large"
  }
}

variable "output_prefix" {
  description = "Prefix for output resources (e.g., kubeconfig file)."
  type        = string
  default     = ""
}
