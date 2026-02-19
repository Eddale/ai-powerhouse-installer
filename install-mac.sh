#!/bin/bash
# =============================================================================
# AI Powerhouse Installer for macOS
# One command to set up everything you need.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/eddale/ai-powerhouse-installer/main/install-mac.sh | bash
#
# What this installs:
#   - Xcode Command Line Tools (provides git)
#   - Homebrew (package manager)
#   - GitHub CLI (repo access)
#   - Claude Code (AI assistant)
#   - Your personal workspace (cloned from template)
#   - Desktop launcher (double-click to start)
#
# Safe to re-run: skips anything already installed.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors and formatting
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

ok()   { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${YELLOW}→${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "\n${BLUE}${BOLD}→ Step $1 of 9:${NC} $2"; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}AI Powerhouse Installer${NC}"
echo "This will set up everything you need for AI Powerhouse."
echo ""

# Must be macOS
if [[ "$(uname)" != "Darwin" ]]; then
    fail "This installer is for macOS only."
    echo "  For Windows, use install-windows.ps1 instead."
    exit 1
fi

# Detect architecture
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
    info "Detected: macOS on Apple Silicon"
else
    BREW_PREFIX="/usr/local"
    info "Detected: macOS on Intel"
fi

# Check internet
if ! curl -fsS --max-time 5 https://github.com > /dev/null 2>&1; then
    fail "No internet connection. Check your WiFi and try again."
    exit 1
fi
ok "Internet connection confirmed"

# Store the GitHub username (will be set during Step 4)
GITHUB_USERNAME=""

# ===========================================================================
# Step 1: Xcode Command Line Tools
# ===========================================================================
step "1" "Checking Xcode Command Line Tools..."

if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools already installed"
else
    info "Installing Xcode Command Line Tools..."
    echo "  A system dialog will appear. Click 'Install' to continue."
    echo "  (This may take a few minutes)"
    echo ""

    # Trigger the install dialog
    xcode-select --install 2>/dev/null || true

    # Wait for installation to complete
    echo "  Waiting for installation to finish..."
    until xcode-select -p &>/dev/null; do
        sleep 5
    done

    if xcode-select -p &>/dev/null; then
        ok "Xcode Command Line Tools installed"
    else
        fail "Xcode Command Line Tools installation failed."
        echo "  Try running: xcode-select --install"
        exit 1
    fi
fi

# ===========================================================================
# Step 2: Homebrew
# ===========================================================================
step "2" "Checking Homebrew..."

if command -v brew &>/dev/null; then
    BREW_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
    ok "Homebrew already installed (${BREW_VERSION})"
else
    info "Installing Homebrew..."
    echo "  You may be asked for your Mac password (the one you use to log in)."
    echo ""

    # Install Homebrew (non-interactive)
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Make Homebrew available in THIS session immediately
    # This is the step that trips people up when doing it manually —
    # Homebrew prints "Run these two commands" but people miss it.
    if [[ -f "$BREW_PREFIX/bin/brew" ]]; then
        eval "$($BREW_PREFIX/bin/brew shellenv)"
    fi

    # Make it permanent (add to shell profile if not already there)
    if [[ "$ARCH" == "arm64" ]]; then
        if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
            echo '' >> "$HOME/.zprofile"
            echo '# Homebrew (added by AI Powerhouse installer)' >> "$HOME/.zprofile"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        fi
    fi

    if command -v brew &>/dev/null; then
        ok "Homebrew installed"
    else
        fail "Homebrew installation failed."
        echo "  Visit https://brew.sh for manual installation."
        exit 1
    fi
fi

# ===========================================================================
# Step 3: GitHub CLI
# ===========================================================================
step "3" "Checking GitHub CLI..."

if command -v gh &>/dev/null; then
    GH_VERSION=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
    ok "GitHub CLI already installed (v${GH_VERSION})"
else
    info "Installing GitHub CLI..."
    brew install gh 2>/dev/null

    if command -v gh &>/dev/null; then
        ok "GitHub CLI installed"
    else
        fail "GitHub CLI installation failed."
        echo "  Try running: brew install gh"
        exit 1
    fi
fi

# ===========================================================================
# Step 4: GitHub Authentication
# ===========================================================================
step "4" "Checking GitHub authentication..."

if gh auth status &>/dev/null 2>&1; then
    GITHUB_USERNAME=$(gh api user --jq '.login' 2>/dev/null || echo "")
    ok "Already logged in to GitHub as ${GITHUB_USERNAME}"
else
    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │  Your browser will open for GitHub login.       │"
    echo "  │  Sign in, then come back to this window.        │"
    echo "  └─────────────────────────────────────────────────┘"
    echo ""

    gh auth login --hostname github.com --git-protocol https --web

    if gh auth status &>/dev/null 2>&1; then
        GITHUB_USERNAME=$(gh api user --jq '.login' 2>/dev/null || echo "")
        ok "Logged in to GitHub as ${GITHUB_USERNAME}"
    else
        fail "GitHub login failed. Try running: gh auth login"
        exit 1
    fi
fi

# If we still don't have the username, fetch it
if [[ -z "$GITHUB_USERNAME" ]]; then
    GITHUB_USERNAME=$(gh api user --jq '.login' 2>/dev/null || echo "")
fi

if [[ -z "$GITHUB_USERNAME" ]]; then
    fail "Could not determine your GitHub username."
    echo "  Try running: gh auth login"
    exit 1
fi

# ===========================================================================
# Step 5: Starter Repo Access
# ===========================================================================
step "5" "Checking AI Powerhouse Starter access..."

if gh api repos/eddale/ai-powerhouse-starter --jq '.name' &>/dev/null 2>&1; then
    ok "You have access to the AI Powerhouse Starter template"
else
    echo ""
    echo "  You don't have access to the AI Powerhouse template yet."
    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │  Check your email for an invitation from Ed.    │"
    echo "  │  Or go to: github.com/notifications             │"
    echo "  │  Accept the invitation, then press Enter here.  │"
    echo "  └─────────────────────────────────────────────────┘"
    echo ""

    while true; do
        read -r -p "  Press Enter after accepting the invitation (or type 'skip' to continue)... "
        if [[ "$REPLY" == "skip" ]]; then
            echo ""
            info "Skipping starter repo check. You can accept the invitation later."
            break
        fi
        if gh api repos/eddale/ai-powerhouse-starter --jq '.name' &>/dev/null 2>&1; then
            ok "Access confirmed"
            break
        else
            echo "  Still no access. Make sure you've accepted the invitation at github.com/notifications"
        fi
    done
fi

# ===========================================================================
# Step 6: Personal Repository
# ===========================================================================
step "6" "Checking your personal repository..."

# Check if they already have a my-powerhouse repo on GitHub
if gh repo view "${GITHUB_USERNAME}/my-powerhouse" &>/dev/null 2>&1; then
    ok "Your personal repository already exists: ${GITHUB_USERNAME}/my-powerhouse"
else
    # Check if they have access to the template before trying to create from it
    if gh api repos/eddale/ai-powerhouse-starter --jq '.name' &>/dev/null 2>&1; then
        info "Creating your personal repository from template..."

        gh repo create my-powerhouse \
            --template eddale/ai-powerhouse-starter \
            --private \
            --confirm 2>/dev/null

        if gh repo view "${GITHUB_USERNAME}/my-powerhouse" &>/dev/null 2>&1; then
            ok "Repository created: ${GITHUB_USERNAME}/my-powerhouse"
        else
            fail "Could not create repository."
            echo "  Try manually at: https://github.com/eddale/ai-powerhouse-starter/generate"
            echo "  Name it: my-powerhouse"
            echo "  Set it to: Private"
            echo "  Then re-run this installer."
            exit 1
        fi
    else
        info "Skipping repository creation (no access to template yet)."
        echo "  Once you accept Ed's invitation, re-run this installer."
    fi
fi

# ===========================================================================
# Step 7: Local Clone
# ===========================================================================
step "7" "Checking local workspace..."

WORKSPACE="$HOME/Documents/my-powerhouse"

if [[ -d "$WORKSPACE" ]]; then
    # Workspace exists — check it's pointing to the RIGHT repo
    CURRENT_REMOTE=$(cd "$WORKSPACE" && git remote get-url origin 2>/dev/null || echo "unknown")

    if echo "$CURRENT_REMOTE" | grep -qi "${GITHUB_USERNAME}/my-powerhouse"; then
        ok "Local workspace exists and points to your repository"

        # Pull latest changes
        info "Updating workspace..."
        (cd "$WORKSPACE" && git pull --quiet 2>/dev/null) || true
        ok "Workspace updated"
    else
        # Wrong repo detected!
        echo ""
        echo -e "  ${YELLOW}⚠ Your local workspace is connected to the wrong repository.${NC}"
        echo "  Current:  ${CURRENT_REMOTE}"
        echo "  Expected: ${GITHUB_USERNAME}/my-powerhouse"
        echo ""
        echo "  This can happen if you cloned Ed's template directly."
        echo "  Your files are safe — we'll rename the folder and set up correctly."
        echo ""
        read -r -p "  Rename existing folder to my-powerhouse-backup? [y/N] " RENAME_CONFIRM

        if [[ "$RENAME_CONFIRM" =~ ^[Yy]$ ]]; then
            BACKUP_NAME="my-powerhouse-backup-$(date +%Y%m%d-%H%M%S)"
            mv "$WORKSPACE" "$HOME/Documents/$BACKUP_NAME"
            ok "Existing folder renamed to $BACKUP_NAME"
        else
            fail "Cannot continue with wrong repository connection."
            echo "  Please rename or remove ~/Documents/my-powerhouse/ and re-run."
            exit 1
        fi
    fi
fi

# Clone if workspace doesn't exist (or was just renamed)
if [[ ! -d "$WORKSPACE" ]]; then
    if gh repo view "${GITHUB_USERNAME}/my-powerhouse" &>/dev/null 2>&1; then
        info "Downloading workspace to your computer..."
        mkdir -p "$HOME/Documents"
        gh repo clone "${GITHUB_USERNAME}/my-powerhouse" "$WORKSPACE" 2>/dev/null

        if [[ -f "$WORKSPACE/CLAUDE.md" ]]; then
            ok "Workspace downloaded to ~/Documents/my-powerhouse"
        else
            fail "Clone succeeded but workspace looks incomplete."
            echo "  Check: ls ~/Documents/my-powerhouse/"
        fi
    else
        info "Skipping clone (repository not yet created)."
        echo "  Re-run this installer after creating your repository."
    fi
fi

# ===========================================================================
# Step 8: Claude Code
# ===========================================================================
step "8" "Checking Claude Code..."

if command -v claude &>/dev/null; then
    # Try to get version (may not work on all versions)
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "installed")
    ok "Claude Code already installed (${CLAUDE_VERSION})"
else
    info "Installing Claude Code..."

    # Run the official installer
    curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null

    # Make it available in THIS session
    # Claude's installer updates shell profiles, so source them
    for profile in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [[ -f "$profile" ]]; then
            source "$profile" 2>/dev/null || true
        fi
    done

    # Fallback: check common install locations
    if ! command -v claude &>/dev/null; then
        for path in "$HOME/.claude/bin" "$HOME/.local/bin" "/usr/local/bin"; do
            if [[ -x "$path/claude" ]]; then
                export PATH="$path:$PATH"
                break
            fi
        done
    fi

    # Make sure ~/.local/bin is in .zshrc permanently (not just this session)
    # The Claude installer sometimes misses this, especially after a bash→zsh switch
    if [[ -x "$HOME/.local/bin/claude" ]]; then
        if ! grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null; then
            echo '' >> "$HOME/.zshrc"
            echo '# Claude Code (added by AI Powerhouse installer)' >> "$HOME/.zshrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        fi
    fi

    if command -v claude &>/dev/null; then
        ok "Claude Code installed"
    else
        fail "Claude Code installation may need a new terminal session."
        echo "  Close this Terminal, open a new one, and run: claude --version"
        echo "  If that works, re-run this installer to complete setup."
    fi
fi

# ===========================================================================
# Step 9: Desktop Launcher
# ===========================================================================
step "9" "Checking desktop launcher..."

LAUNCHER="$HOME/Desktop/AI Powerhouse.command"

if [[ -f "$LAUNCHER" ]]; then
    ok "Desktop launcher already exists"
else
    info "Creating desktop launcher..."

    cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
# AI Powerhouse Launcher
# Double-click this file to start Claude Code in your workspace.

cd ~/Documents/my-powerhouse && claude
LAUNCHER_EOF

    chmod +x "$LAUNCHER"

    if [[ -f "$LAUNCHER" ]]; then
        ok "Desktop launcher created: AI Powerhouse.command"
    else
        fail "Could not create desktop launcher."
        echo "  You can still start manually: cd ~/Documents/my-powerhouse && claude"
    fi
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "==========================================="
echo -e "${GREEN}${BOLD}  Setup Complete!${NC}"
echo "==========================================="
echo ""
echo "  Your AI Powerhouse workspace is ready."
echo ""
echo "  What's been set up:"
echo -e "    ${GREEN}•${NC} GitHub CLI (connected as ${GITHUB_USERNAME})"
echo -e "    ${GREEN}•${NC} Claude Code"

if [[ -d "$WORKSPACE" ]]; then
echo -e "    ${GREEN}•${NC} Your workspace: ~/Documents/my-powerhouse"
fi

echo -e "    ${GREEN}•${NC} Desktop launcher: AI Powerhouse.command"
echo ""
echo "  ┌─────────────────────────────────────────────────┐"
echo "  │  HOW TO START:                                  │"
echo "  │                                                 │"
echo "  │  Double-click 'AI Powerhouse' on your Desktop   │"
echo "  │                                                 │"
echo "  │  First time? Type:  build my mission context    │"
echo "  │  Need new skills?   Type:  get new skills       │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
echo "  Or from Terminal:"
echo "    cd ~/Documents/my-powerhouse && claude"
echo ""
echo "  See you at the Lab!"
echo ""
