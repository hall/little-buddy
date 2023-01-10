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
          packages = {
            bestool = pkgs.rustPlatform.buildRustPackage rec {
              pname = "bestool";
              version = "1921815e80e0f4fc4260d612590d8334c612e932";
              src = pkgs.fetchFromGitHub
                {
                  owner = "Ralim";
                  repo = pname;
                  rev = version;
                  sha256 = "sha256-xxCyA4swjdloLtTxmPQY3anz+Kc4XWRPZtlDsr/s5v8=";
                  fetchSubmodules = true;
                };
              cargoSha256 = "sha256-NeXt3Sggxq8rEfMd16AHHYTzI0A9oRFhvp72A0TIEeA=";
              sourceRoot = "source/${pname}";
              nativeBuildInputs = with pkgs; [
                pkg-config
              ];
              buildInputs = with pkgs;[
                udev
              ];
            };

            default = pkgs.stdenv.mkDerivation rec {
              name = "little-buddy";
              src = ./.;
              makeFlags = [ "-j" ];
              nativeBuildInputs = with pkgs; [
                # https://github.com/NixOS/nixpkgs/issues/51907
                gcc-arm-embedded-9

                bc
                hostname
                flashrom
                minicom
                self.packages.${system}.bestool
              ];
              installPhase = ''
                version=$(cat CHANGELOG.md | grep '^## \[[0-9]' | head -1 | cut -d "[" -f2 | cut -d "]" -f1)

                mkdir -p $out
                mv ./out/firmware.bin $out/${name}-$version.bin
              '';
            };
          };
        });
}
