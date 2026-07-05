{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Personal cross-machine config; consumed piecemeal via its exported
    # homeModules rather than deployed wholesale.
    personal.url = "github:ShaneEverittM/nix/main";

    # Needed to host home-manager modules (like personal's git one) inside the
    # NixOS build. Follows our nixpkgs so we don't evaluate a second one.
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Make flake inputs visible to modules (configuration.nix takes `inputs`).
        specialArgs = { inherit inputs; };
        modules = [ ./configuration.nix ];
      };
    };
}
