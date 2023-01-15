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
          apps = {
            flash = inputs.utils.lib.mkApp {
              drv = pkgs.writeShellScriptBin "tts" ''
                # should correctly identify the pinebuds
                id=/dev/serial/by-id/usb-wch.cn_USB_Dual_Serial_0123456789-if
                for i in 00 02; do
                  # use the given file or a default
                  [ $# -eq 1 ] && bin=$1 || bin=result/little-buddy-*-''${LANGUAGE:-en}.bin
                  ${self.packages.${system}.bestool}/bin/bestool write-image --port $id$i $bin 
                done
              '';
            };
            tts = inputs.utils.lib.mkApp {
              drv = pkgs.writeShellScriptBin "tts" ''
                LANGUAGE=$1
                dir=./config/res/spoken/$LANGUAGE
                (rm -r $dir || true) && mkdir $dir

                readarray -d "" files < <(find $(dirname $dir)/en -type f -print0)
                for file in "''${files[@]}"; do
                  phrase=$(basename $file .wav | sed "s/SOUND_//" | tr "_" " ")
                  ${pkgs.translate-shell}/bin/trans -b :$LANGUAGE "$phrase" -download-audio-as ''${file/\/en\//\/$L\/};
                done
              '';
            };
          };
          packages = {
            bestool = pkgs.rustPlatform.buildRustPackage rec {
              pname = "bestool";
              version = "1921815e80e0f4fc4260d612590d8334c612e932";
              src = pkgs.fetchFromGitHub {
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
              nativeBuildInputs = with pkgs; [
                # https://github.com/NixOS/nixpkgs/issues/51907
                gcc-arm-embedded-9

                bc
                hostname

                # serial
                minicom
                self.packages.${system}.bestool

                # audio
                ffmpeg
                xxd
              ];
              buildPhase = ''
                find ./config/res/spoken -maxdepth 1 -mindepth 1 -type d -exec sh -c 'make -j LANGUAGE=$(basename {})' \;
              '';
              installPhase = ''
                version=$(cat CHANGELOG.md | grep '^## \[[0-9]' | head -1 | cut -d "[" -f2 | cut -d "]" -f1)

                ${pkgs.util-linux}/bin/rename firmware ${name}-$version ./out/firmware-*.bin 
                mkdir -p $out
                mv ./out/*.bin $out/
              '';
            };
          };
        });
}
