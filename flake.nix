{
  description = "Repro: stale crate-hashes.json for branch-based git deps";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crate2nix.url = "github:nix-community/crate2nix";
  };

  outputs = { self, nixpkgs, crate2nix, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          cargoNix = pkgs.callPackage ./Cargo.nix {
            buildRustCrateForPkgs = pkgs: pkgs.buildRustCrate.override {
              defaultCrateOverrides = pkgs.defaultCrateOverrides;
            };
          };
        in
        {
          default = cargoNix.rootCrate.build;
        }
      );

      apps = forAllSystems (system:
        let
          crate2nix-bin = crate2nix.packages.${system}.default;
        in
        {
          generate = {
            type = "app";
            program = "${crate2nix-bin}/bin/crate2nix";
          };
        }
      );
    };
}
