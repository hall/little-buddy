{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  };

  outputs = inputs@{ self, ... }:
    inputs.utils.lib.eachDefaultSystem (system:
      let pkgs = inputs.nixpkgs.legacyPackages.${system}; in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          name = "little-buddy";
          src = ./.;
          makeFlags = [
            # "-j"
            "T=open_source"
          ];
          nativeBuildInputs = with pkgs; [
            # https://github.com/NixOS/nixpkgs/issues/51907
            gcc-arm-embedded-9

            bc
            hostname
            flashrom
            minicom
          ];
        };
      });
}
