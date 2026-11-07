#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { printf "${GREEN}==>${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}==>${NC} %s\n" "$*"; }
err()  { printf "${RED}==>${NC} %s\n" "$*"; }
info() { printf "${CYAN}..${NC} %s\n" "$*"; }

# ── Check OS ────────────────────────────────────────────────────────────────
if [ "$(uname -s)" != "Linux" ]; then
  err "This script only supports Linux (Ubuntu)."
  err "Detected: $(uname -s)"
  exit 1
fi

if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
  warn "This script is tested on Ubuntu. Other Linux distros may need adjustments."
fi

# ── Detect shell rc file ─────────────────────────────────────────────────
detect_rc() {
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
    echo "$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ] || [ -f "$HOME/.bashrc" ]; then
    echo "$HOME/.bashrc"
  elif [ -f "$HOME/.bash_profile" ]; then
    echo "$HOME/.bash_profile"
  else
    echo "$HOME/.profile"
  fi
}
RC_FILE="$(detect_rc)"
info "Detected shell rc: $RC_FILE"

# ── Helper: add to PATH in rc file if not already there ───────────────────
add_to_path() {
  local dir="$1"
  local line="export PATH=\"$dir:\$PATH\""
  if ! grep -qF "$line" "$RC_FILE" 2>/dev/null; then
    echo "$line" >> "$RC_FILE"
    log "Added $dir to PATH in $RC_FILE"
  else
    info "$dir already in PATH"
  fi
}

# ── Install system dependencies ───────────────────────────────────────────
install_system_deps() {
  log "Installing system packages..."
  sudo apt-get update
  sudo apt-get install -y curl git python3 python3-pip python3-venv pipx
  pipx ensurepath
  add_to_path "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
}

# ── Install tofuenv + OpenTofu ───────────────────────────────────────────
install_tofu() {
  log "Installing tofuenv + OpenTofu..."

  if command -v tofu &>/dev/null; then
    info "tofu already installed ($(tofu --version 2>&1 | head -1))"
    return
  fi

  if [ -d "$HOME/.tofuenv" ]; then
    info "tofuenv already cloned — updating"
    git -C "$HOME/.tofuenv" pull --ff-only --quiet 2>/dev/null || true
  else
    git clone --depth=1 https://github.com/tofuenv/tofuenv "$HOME/.tofuenv"
  fi

  # Source tofuenv for this session
  # tofuenv uses a different init pattern depending on version
  if [ -f "$HOME/.tofuenv/bin/tofuenv" ]; then
    export PATH="$HOME/.tofuenv/bin:$PATH"
    add_to_path "$HOME/.tofuenv/bin"
  fi

  # Install a pinned OpenTofu version (kept in sync with CI's TOFU_VERSION in
  # .github/workflows/module-review.yml — bump both together).
  # tofuenv install <version>, tofuenv use <version> sets the active one
  info "Installing OpenTofu 1.13.2 via tofuenv..."
  TOFU_VERSION="1.13.2"
  eval "$("$HOME/.tofuenv/bin/tofuenv" init -)"
  "$HOME/.tofuenv/bin/tofuenv" install "$TOFU_VERSION"
  "$HOME/.tofuenv/bin/tofuenv" use "$TOFU_VERSION"

  if command -v tofu &>/dev/null; then
    log "OpenTofu $(tofu --version 2>&1 | head -1) installed"
  else
    warn "tofuenv installed but 'tofu' not in PATH yet — source your rc file or open a new terminal"
  fi
}

# ── Install checkov ───────────────────────────────────────────────────────
install_checkov() {
  log "Installing checkov..."

  if command -v checkov &>/dev/null; then
    info "checkov already installed ($(checkov --version 2>&1 | head -1))"
    return
  fi

  pipx install checkov
  if command -v checkov &>/dev/null; then
    log "checkov installed"
  else
    warn "checkov installation may need a new terminal or 'source $RC_FILE'"
  fi
}

# ── Install opa ───────────────────────────────────────────────────────────
install_opa() {
  log "Installing OPA..."

  if command -v opa &>/dev/null; then
    info "opa already installed ($(opa version 2>&1 | head -1))"
    return
  fi

  curl -fSL "https://github.com/open-policy-agent/opa/releases/download/v1.20.2/opa_linux_amd64" -o /tmp/opa
  sudo mv /tmp/opa /usr/local/bin/opa
  sudo chmod +x /usr/local/bin/opa

  if command -v opa &>/dev/null; then
    log "opa installed ($(opa version 2>&1 | head -1))"
  else
    err "opa installation failed"
  fi
}

# ── Install infracost ─────────────────────────────────────────────────────
install_infracost() {
  log "Installing Infracost..."

  if command -v infracost &>/dev/null; then
    info "infracost already installed ($(infracost --version 2>&1 | head -1))"
    return
  fi

  curl -fsSL "https://raw.githubusercontent.com/infracost/cli/master/scripts/install.sh" | sh -
  # Install script places it in /usr/local/bin by default
  if command -v infracost &>/dev/null; then
    log "infracost installed ($(infracost --version 2>&1))"
    info "Run 'infracost configure set api_key YOUR_KEY' to enable cost estimates"
    info "Get a free API key at https://dashboard.infracost.io"
  else
    warn "infracost may need manual installation — see https://infracost.io/docs/#quick-start"
  fi
}

# ── Verify installation ──────────────────────────────────────────────────
verify() {
  log "Verifying installation..."
  local all_ok=true

  for tool in tofu checkov opa infracost; do
    if command -v "$tool" &>/dev/null; then
      printf "  ${GREEN}✅${NC} %s\n" "$tool"
    else
      printf "  ${YELLOW}⚠️  ${NC} %s — not found (may need a new terminal or manual install)\n" "$tool"
      all_ok=false
    fi
  done

  if $all_ok; then
    log "All tools installed!"
  else
    warn "Some tools are missing. Open a new terminal or 'source $RC_FILE' and re-run if needed."
  fi
}

# ── Run ──────────────────────────────────────────────────────────────────
info "Starting dev environment setup for Anestoa Infrastructure"
install_system_deps
install_tofu
install_checkov
install_opa
install_infracost
verify

log "Setup complete!"
echo ""
echo "  Next steps:"
echo "    source $RC_FILE    # or open a new terminal"
echo "    make review          # run the full audit on the current module"
echo "    make setup           # idempotent — safe to re-run anytime"
echo ""