#!/bin/bash
# Devbox Installer
# Installs the devbox CLI, bash completion, and optionally builds the Docker image

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default installation prefix
DEFAULT_PREFIX="/usr/local"
PREFIX="${PREFIX:-$DEFAULT_PREFIX}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Options
DRY_RUN=false
UNINSTALL=false
SKIP_IMAGE=false
SKIP_COMPLETION=false
VERBOSE=false

# Logging functions
log_info() {
    echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}  →${NC} $*"
    fi
}

# Usage function
usage() {
    cat << EOF
Devbox Installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    --prefix <path>      Installation prefix (default: $DEFAULT_PREFIX)
                         Binary installed to <prefix>/bin/devbox
                         Completion installed to <prefix>/share/bash-completion/completions/
    --uninstall          Remove devbox from the system
    --skip-image         Skip building the Docker image
    --skip-completion    Skip installing bash completion
    --dry-run            Show what would be done without executing
    --verbose            Show detailed output
    -h, --help           Show this help message

EXAMPLES:
    # Standard installation (requires sudo)
    sudo ./install.sh

    # Install to user directory (no sudo needed)
    ./install.sh --prefix ~/.local

    # Uninstall from default location
    sudo ./install.sh --uninstall

    # Install without building Docker image
    ./install.sh --prefix ~/.local --skip-image

    # See what would be installed
    ./install.sh --dry-run

ENVIRONMENT VARIABLES:
    PREFIX               Alternative to --prefix flag

NOTES:
    - For system-wide installation to /usr/local, run with sudo
    - For user installation, use --prefix ~/.local and add ~/.local/bin to PATH
    - Bash completion requires sourcing or restarting your shell

EOF
}

# Check if we can write to the prefix
check_write_permission() {
    local dir="$1"

    # Create parent directories if needed (for dry-run checking)
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    # Check if directory exists and is writable
    if [[ -d "$dir" ]]; then
        if [[ ! -w "$dir" ]]; then
            return 1
        fi
    else
        # Check if parent is writable
        local parent
        parent=$(dirname "$dir")
        if [[ -d "$parent" ]] && [[ ! -w "$parent" ]]; then
            return 1
        fi
    fi

    return 0
}

# Execute or show command
run_cmd() {
    local cmd="$*"

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would run: $cmd"
        return 0
    fi

    log_verbose "$cmd"
    eval "$cmd"
}

# Install the devbox binary
install_binary() {
    local bin_dir="$PREFIX/bin"
    local source="$SCRIPT_DIR/bin/devbox"
    local dest="$bin_dir/devbox"

    log_info "Installing devbox binary to $dest"

    if [[ ! -f "$source" ]]; then
        log_error "Source binary not found: $source"
        return 1
    fi

    # Create bin directory if needed
    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create directory: $bin_dir"
        echo "  Would copy: $source -> $dest"
        echo "  Would chmod +x $dest"
    else
        mkdir -p "$bin_dir"
        cp "$source" "$dest"
        chmod +x "$dest"
        log_success "Binary installed to $dest"
    fi
}

# Install bash completion
install_completion() {
    local completion_source="$SCRIPT_DIR/completions/devbox.bash"
    local completion_dir="$PREFIX/share/bash-completion/completions"
    local completion_dest="$completion_dir/devbox"

    log_info "Installing bash completion to $completion_dest"

    if [[ ! -f "$completion_source" ]]; then
        log_error "Completion file not found: $completion_source"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would create directory: $completion_dir"
        echo "  Would copy: $completion_source -> $completion_dest"
    else
        mkdir -p "$completion_dir"
        cp "$completion_source" "$completion_dest"
        log_success "Completion installed to $completion_dest"

        # Provide instructions for sourcing
        echo
        log_info "To enable completion immediately, run:"
        echo "  source $completion_dest"
        echo
        log_info "To enable permanently, add to your ~/.bashrc:"
        echo "  source $completion_dest"
    fi
}

# Build Docker image
build_image() {
    local dockerfile_dir="$SCRIPT_DIR/docker"
    local image_name="devbox-base:latest"

    log_info "Building Docker image $image_name"

    if [[ ! -f "$dockerfile_dir/Dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile_dir/Dockerfile"
        return 1
    fi

    # Check if Docker is available
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would run: docker build -t $image_name $dockerfile_dir"
    else
        log_info "This may take several minutes..."
        if docker build -t "$image_name" "$dockerfile_dir"; then
            log_success "Docker image $image_name built successfully"
        else
            log_error "Failed to build Docker image"
            return 1
        fi
    fi
}

# Uninstall devbox
uninstall() {
    local bin_file="$PREFIX/bin/devbox"
    local completion_file="$PREFIX/share/bash-completion/completions/devbox"

    log_info "Uninstalling devbox from $PREFIX"

    # Remove binary
    if [[ -f "$bin_file" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would remove: $bin_file"
        else
            rm -f "$bin_file"
            log_success "Removed $bin_file"
        fi
    else
        log_info "Binary not found at $bin_file (already removed?)"
    fi

    # Remove completion
    if [[ -f "$completion_file" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo "  Would remove: $completion_file"
        else
            rm -f "$completion_file"
            log_success "Removed $completion_file"
        fi
    else
        log_info "Completion not found at $completion_file (already removed?)"
    fi

    log_success "Uninstall complete"
    echo
    log_info "Note: Docker image 'devbox-base:latest' was NOT removed."
    log_info "To remove it, run: docker rmi devbox-base:latest"
}

# Main installation
install() {
    log_info "Installing devbox to $PREFIX"
    echo

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN - showing what would be done"
        echo
    fi

    # Check write permissions
    if ! check_write_permission "$PREFIX"; then
        log_error "Cannot write to $PREFIX"
        log_error "Try running with sudo or use --prefix to install elsewhere"
        return 1
    fi

    # Install binary
    if ! install_binary; then
        log_error "Failed to install binary"
        return 1
    fi

    # Install completion (unless skipped)
    if [[ "$SKIP_COMPLETION" != true ]]; then
        if ! install_completion; then
            log_warning "Failed to install completion (non-fatal)"
        fi
    else
        log_info "Skipping completion installation"
    fi

    # Build Docker image (unless skipped)
    if [[ "$SKIP_IMAGE" != true ]]; then
        echo
        if ! build_image; then
            log_warning "Failed to build Docker image (non-fatal)"
            log_info "You can build it later with: docker build -t devbox-base:latest $SCRIPT_DIR/docker"
        fi
    else
        log_info "Skipping Docker image build"
    fi

    echo
    log_success "Installation complete!"
    echo

    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":$PREFIX/bin:"* ]]; then
        log_warning "$PREFIX/bin is not in your PATH"
        log_info "Add it to your shell profile:"
        echo "  export PATH=\"$PREFIX/bin:\$PATH\""
    fi
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                PREFIX="$2"
                shift 2
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --skip-image)
                SKIP_IMAGE=true
                shift
                ;;
            --skip-completion)
                SKIP_COMPLETION=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                echo
                usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                echo
                usage
                exit 1
                ;;
        esac
    done
}

# Main entry point
main() {
    parse_args "$@"

    echo
    echo "====================================="
    echo "  Devbox Installer"
    echo "====================================="
    echo

    if [[ "$UNINSTALL" == true ]]; then
        uninstall
    else
        install
    fi
}

main "$@"
