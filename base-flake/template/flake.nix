{
  description = "Project development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Devbox base platform - provides git, gh, claude, aws, shell tools, etc.
    devbox.url = "github:system1/devbox?dir=base-flake";
  };

  outputs = { self, nixpkgs, flake-utils, devbox }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          # Inherit all base platform tools from devbox
          inputsFrom = [
            devbox.devShells.${system}.default
          ];

          # Add project-specific packages here
          buildInputs = with pkgs; [
            # Example: Uncomment and add your project's dependencies
            # nodejs_20
            # python311
            # terraform
            # docker-compose
          ];

          shellHook = ''
            echo "🚀 Project Development Environment"
            echo ""
            echo "Base platform tools inherited from devbox:"
            echo "  • git, gh, claude, aws, jq, vim, shellcheck, etc."
            echo ""
            echo "Project-specific tools:"
            echo "  • (Add your project dependencies to buildInputs above)"
            echo ""

            # Add project-specific setup commands here
            # Example:
            # export DATABASE_URL="postgresql://localhost/mydb"
            # echo "Starting development server on port 3000..."
          '';
        };
      }
    );
}
