{
  description = "Devbox - CLI tool for managing isolated, authenticated development containers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core development tools
            bash
            git
            docker
            docker-compose

            # CLI development and testing
            shellcheck       # Bash linting and static analysis
            shfmt           # Bash formatter
            bats            # Bash testing framework (alternative to custom tests)

            # Text editors and development
            vim
            nano

            # Utilities for development workflow
            curl
            jq              # JSON processing (useful for Docker API interactions)
            tree            # Directory tree visualization
            htop            # Process monitoring

            # GitHub CLI (for testing/development workflows)
            gh

            # Node.js and Claude Code (matching the Docker environment)
            nodejs_20
          ] ++ lib.optionals stdenv.isDarwin [
            # macOS-specific tools
            colima          # Docker Desktop alternative for macOS
          ];

          shellHook = ''
            echo "🛠️  Devbox development environment loaded"
            echo ""
            echo "Available tools:"
            echo "  • docker          - Container management (ensure Docker daemon is running)"
            echo "  • shellcheck      - Bash linting (shellcheck bin/devbox tests/*.sh)"
            echo "  • shfmt          - Bash formatting (shfmt -w bin/devbox tests/*.sh)"
            echo "  • gh             - GitHub CLI"
            echo "  • jq             - JSON processing"
            echo "  • tree           - Directory visualization"
            echo ""
            echo "Development workflow:"
            echo "  • Run tests:      ./tests/test_cli_basic.sh"
            echo "  • Build image:    docker build -t devbox-base:latest docker/"
            echo "  • Test CLI:       ./bin/devbox help"
            echo "  • Lint code:      shellcheck bin/devbox tests/*.sh"
            echo "  • Format code:    shfmt -w bin/devbox tests/*.sh"
            echo ""

            # Check if Docker is available
            if command -v docker >/dev/null 2>&1; then
              if docker info >/dev/null 2>&1; then
                echo "✅ Docker daemon is running"
              else
                echo "⚠️  Docker is installed but daemon is not running"
                echo "   Start Docker Desktop or run 'colima start' (on macOS)"
              fi
            else
              echo "❌ Docker not found in PATH"
              echo "   On macOS: Install Docker Desktop or use 'colima'"
            fi
            echo ""

            # Set up some convenience aliases
            alias devbox-test="./tests/test_cli_basic.sh"
            alias devbox-lint="shellcheck bin/devbox tests/*.sh"
            alias devbox-format="shfmt -w bin/devbox tests/*.sh"
            alias devbox-build="docker build -t devbox-base:latest docker/"

            # Make the devbox CLI available in PATH for development
            export PATH="$PWD/bin:$PATH"

            echo "🚀 Ready to develop devbox! Try 'devbox help' to test the CLI"
          '';

          # Environment variables
          DEVBOX_DEV_MODE = "1";
          DOCKER_BUILDKIT = "1";  # Enable BuildKit for better Docker builds
        };

        # Add some additional outputs for convenience
        packages.default = pkgs.stdenv.mkDerivation {
          name = "devbox";
          version = "0.1.0";
          src = ./.;

          buildInputs = [ pkgs.bash ];

          installPhase = ''
            mkdir -p $out/bin
            cp bin/devbox $out/bin/
            chmod +x $out/bin/devbox

            # Install Docker files for reference
            mkdir -p $out/share/devbox/docker
            cp docker/* $out/share/devbox/docker/

            # Install tests for verification
            mkdir -p $out/share/devbox/tests
            cp tests/*.sh $out/share/devbox/tests/
          '';

          meta = with pkgs.lib; {
            description = "CLI tool for managing isolated, authenticated development containers";
            homepage = "https://github.com/your-org/devbox";  # Update with actual repo
            license = licenses.mit;  # Update with actual license
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        # Development checks
        checks = {
          shellcheck = pkgs.stdenv.mkDerivation {
            name = "devbox-shellcheck";
            src = ./.;
            buildInputs = [ pkgs.shellcheck ];
            buildPhase = ''
              shellcheck bin/devbox tests/*.sh
            '';
            installPhase = "touch $out";
          };

          formatting = pkgs.stdenv.mkDerivation {
            name = "devbox-formatting";
            src = ./.;
            buildInputs = [ pkgs.shfmt ];
            buildPhase = ''
              shfmt -d bin/devbox tests/*.sh
            '';
            installPhase = "touch $out";
          };
        };
      });
}