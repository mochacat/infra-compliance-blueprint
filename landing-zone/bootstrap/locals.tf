locals {
  # ── Account email conventions ──
  # Each member account gets <prefix><name>@<domain>
  # e.g. aws-security@anestoa.io
  email = {
    security    = "${var.account_email_prefix}security@${var.account_email_domain}"
    log-archive = "${var.account_email_prefix}log-archive@${var.account_email_domain}"
    network     = "${var.account_email_prefix}network@${var.account_email_domain}"
    # Workload accounts
    production-platform  = "${var.account_email_prefix}prod-platform@${var.account_email_domain}"
    production-research  = "${var.account_email_prefix}prod-research@${var.account_email_domain}"
    production-data      = "${var.account_email_prefix}prod-data@${var.account_email_domain}"
    preprod-platform     = "${var.account_email_prefix}preprod-platform@${var.account_email_domain}"
    preprod-research     = "${var.account_email_prefix}preprod-research@${var.account_email_domain}"
    development-platform = "${var.account_email_prefix}dev-platform@${var.account_email_domain}"
    development-research = "${var.account_email_prefix}dev-research@${var.account_email_domain}"
    sandbox              = "${var.account_email_prefix}sandbox@${var.account_email_domain}"
  }

  # ── OU Paths ──
  ous = {
    root                     = "/"
    infra_control_plane      = "/Infra-Control-Plane"
    infra_ctrl_plane_network = "/Infra-Control-Plane/Network"
    production               = "/Production"
    prod_platform            = "/Production/Platform"
    prod_research            = "/Production/Research"
    prod_data                = "/Production/DataPlatform"
    preprod                  = "/Pre-Production"
    preprod_platform         = "/Pre-Production/Platform"
    preprod_research         = "/Pre-Production/Research"
    development              = "/Development"
    dev_platform             = "/Development/Platform"
    dev_research             = "/Development/Research"
    sandbox                  = "/Sandbox"
  }

  # ── Tags ──
  default_tags = {
    ManagedBy = "tofu"
    Purpose   = "landing-zone-bootstrap"
  }
}

# ── OUs as a flat list for for_each ──
locals {
  ou_definitions = {
    infra_control_plane      = { name = "Infra-Control-Plane" }
    infra_ctrl_plane_network = { name = "Network" }
    production               = { name = "Production" }
    prod_platform            = { name = "Platform" }
    prod_research            = { name = "Research" }
    prod_data                = { name = "DataPlatform" }
    preprod                  = { name = "Pre-Production" }
    preprod_platform         = { name = "Platform" }
    preprod_research         = { name = "Research" }
    development              = { name = "Development" }
    dev_platform             = { name = "Platform" }
    dev_research             = { name = "Research" }
    sandbox                  = { name = "Sandbox" }
  }
}

# ── SCP attachment matrix ──
locals {
  # Map each OU to the list of SCP short names that should attach
  scp_attachments = {
    root                     = ["DenyRootUserActions", "RestrictRegions", "EnforceEncryptionAtRest", "DenyCloudTrailDisable"]
    infra_control_plane      = []
    infra_ctrl_plane_network = []
    production               = ["DenyPublicAccess", "EnforceDeletionProtection", "DenySnapshotSkip"]
    prod_platform            = []
    prod_research            = []
    prod_data                = []
    preprod                  = ["DenyPublicAccess"]
    preprod_platform         = []
    preprod_research         = []
    development              = ["DenyPublicAccess"]
    dev_platform             = []
    dev_research             = []
    sandbox                  = []
  }
}