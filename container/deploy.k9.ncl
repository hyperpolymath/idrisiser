# SPDX-License-Identifier: PMPL-1.0-or-later
# deploy.k9.ncl — {{PROJECT_NAME}} deployment component (Hunt level)
#
# k9-svc deployment specification with full pedigree (L1-L5).
# Security Level: 'Hunt (requires cryptographic handshake for execution).
#
# WARNING: This component can execute shell commands!
# It requires explicit authorisation via the Leash system.
#
# Usage:
#   nickel typecheck container/deploy.k9.ncl
#   k9-svc validate container/deploy.k9.ncl
#   k9-svc deploy container/deploy.k9.ncl --env production

# The component's pedigree (self-description across five layers)
let component_pedigree = {
  # ─────────────────────────────────────────────────────────────
  # L1: The Snout — Identity
  # ─────────────────────────────────────────────────────────────
  metadata = {
    name = "{{SERVICE_NAME}}-deploy",
    version = "{{VERSION}}",
    breed = "application/vnd.k9+nickel",
    magic_number = "K9!",
    description = "{{PROJECT_NAME}} deployment component (Hunt level)",
  },

  # ─────────────────────────────────────────────────────────────
  # L2: The Scent — Target Environment
  # ─────────────────────────────────────────────────────────────
  target = {
    os = 'Linux,
    is_edge = false,
    requires_podman = true,
    min_memory_mb = 256,
  },

  # ─────────────────────────────────────────────────────────────
  # L3: The Leash — Security
  # ─────────────────────────────────────────────────────────────
  security = {
    trust_level = 'Hunt,
    allow_network = true,
    allow_filesystem_write = true,
    allow_subprocess = true,
    # In production, replace with a real Ed25519 signature.
    signature = "PLACEHOLDER-SIGNATURE-REQUIRED-FOR-HUNT",
  },

  # ─────────────────────────────────────────────────────────────
  # L4: The Gut — Self-Validation
  # ─────────────────────────────────────────────────────────────
  validation = {
    checksum = "sha256:placeholder",
    pedigree_version = "1.0.0",
    hunt_authorized = false,  # Must be set true after handshake
  },

  # ─────────────────────────────────────────────────────────────
  # L5: The Muscle — Deployment Recipes
  # ─────────────────────────────────────────────────────────────
  recipes = {
    install = "just container-build",
    validate = "just container-verify",
    deploy = "just container-up",
    migrate = "just container-build && just container-up",
  },
} in

# Deployment configuration
let deployment = {
  # Target environments (dev / staging / production)
  environments = {
    dev = {
      replicas = 1,
      memory = "256Mi",
      cpu = "100m",
      image_tag = "dev",
    },
    staging = {
      replicas = 2,
      memory = "512Mi",
      cpu = "250m",
      image_tag = "staging",
    },
    production = {
      replicas = 3,
      memory = "1Gi",
      cpu = "500m",
      image_tag = "latest",
    },
  },

  # Container configuration
  container = {
    image = "{{REGISTRY}}/{{SERVICE_NAME}}",
    port = {{PORT}},
    health_check = "/health",
    readiness_check = "/ready",
  },

  # Deployment strategy
  strategy = {
    type = "rolling",
    max_surge = 1,
    max_unavailable = 0,
  },
} in

# Deployment scripts (executed at Hunt level)
let scripts = {
  # Pre-deployment validation
  pre_deploy = m%"
#!/bin/sh
set -eu
echo "K9: Pre-deployment validation for {{SERVICE_NAME}}..."
cd container && selur-compose verify || podman compose --file compose.toml config
echo "K9: Validation passed."
"%,

  # Deployment script
  deploy = m%"
#!/bin/sh
set -eu
ENV="${1:-dev}"
echo "K9: Deploying {{SERVICE_NAME}} to $ENV environment..."
cd container
./ct-build.sh
selur-compose up --detach || podman compose --file compose.toml up --detach
echo "K9: Deployment to $ENV complete."
"%,

  # Rollback script
  rollback = m%"
#!/bin/sh
set -eu
echo "K9: Rolling back {{SERVICE_NAME}} deployment..."
cd container
selur-compose down || podman compose --file compose.toml down
echo "K9: Rollback complete."
"%,
} in

# Export the component
{
  pedigree = component_pedigree,
  deployment = deployment,
  scripts = scripts,

  # Security check: this component requires Hunt level
  required_level = 'Hunt,

  # Warning for users
  warning = m%"
WARNING: This is a Hunt-level component.

It can execute shell commands and modify your system.
Before running, ensure you have:

1. Reviewed the deployment scripts above
2. Verified the signature (when implemented)
3. Explicitly authorised Hunt-level execution

Run with: k9-svc authorize container/deploy.k9.ncl && k9-svc deploy container/deploy.k9.ncl
"%,
}
