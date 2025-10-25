module "cluster_control" {
  source = "./cluster"

  name = "control"

  image_name = var.image_name
  image_id   = var.image_id
}
