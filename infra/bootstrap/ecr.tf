# The image registry outlives any single environment apply, so it is created here.
module "ecr_api" {
  source = "../modules/ecr"

  name_prefix     = "${var.project}-${var.environment}"
  repository_name = "api"
  force_delete    = true # demo: allow full teardown
}
