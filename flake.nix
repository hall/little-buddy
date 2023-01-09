{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  };

  outputs = inputs@{ self, ... }:
    with inputs.utils.lib; eachSystem
      # `gcc-arm-embedded-9` not supported on `aarch64-darwin`
      (with system; [
        x86_64-linux
        aarch64-linux
      ])
      (system:
        let pkgs = inputs.nixpkgs.legacyPackages.${system}; in
        {
          packages.default = pkgs.stdenv.mkDerivation rec {
            name = "little-buddy";
            version = "0.0.0"; # TODO: get version from tags?
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
            installPhase = ''
              mkdir -p $out
              mv ./out/open_source/open_source.bin $out/${name}-${version}.bin
            '';
          };
        });
}
