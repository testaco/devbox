{
  description = "Devbox base platform - provides core development tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs = { self, nixpkgs, flake-utils, claude-code }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Core platform packages available to all devboxes
        basePackages = with pkgs; [
          # Shell essentials
          bash
          coreutils
          findutils
          gnugrep
          gnused

          # Git and GitHub
          git
          gh

          # Utilities
          curl
          jq
          yq-go
          tree
          htop
          wget

          # Editors
          vim
          nano

          # AWS CLI
          awscli2
        ] ++ [
          # Claude Code from external flake
          claude-code.packages.${system}.default
        ];
      in
      {
        # Export base packages for composition
        lib = {
          inherit basePackages;
        };

        # Default dev shell with all platform tools
        devShells.default = pkgs.mkShell {
          buildInputs = basePackages;

          shellHook = ''
            echo "🛠️  Devbox Platform Environment"
            echo ""
            echo "Available tools:"
            echo "  • git, gh          - Git and GitHub CLI"
            echo "  • claude           - Claude Code AI assistant"
            echo "  • aws              - AWS CLI v2"
            echo "  • jq, yq           - JSON and YAML processing"
            echo "  • vim, nano        - Text editors"
            echo "  • tree, htop       - System utilities"
            echo ""
          '';
        };

        # Template for project flakes
        templates.default = {
          path = ./template;
          description = "Devbox project template with base platform";
        };
      }
    );
}
