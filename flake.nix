{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    pre-commit.url = "github:cachix/pre-commit-hooks.nix";
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
          formatter = pkgs.treefmt;
          apps = {
            flash = inputs.utils.lib.mkApp {
              drv = pkgs.writeShellScriptBin "flash" ''
                LANGUAGE=en

                while [[ $# -gt 0 ]]; do
                  case $1 in
                    -v|--version)
                      VERSION="$2"
                      shift 2;;
                    -l|--language)
                      LANGUAGE="$2"
                      shift 2;;
                    -*)
                      echo "unknown option: $1"
                      echo "usage: $0 -- [-v <version>] [-l <language>]"
                      echo "       $0 <path/to/firmware.bin>"
                      exit 1;;
                    *)
                      BIN="$1"
                      shift;;
                  esac
                done

                if [ ! -n "$VERSION" ]; then
                  VERSION=$(${pkgs.curl}/bin/curl -s https://api.github.com/repos/hall/little-buddy/releases/latest | ${pkgs.jq}/bin/jq -r '.name')
                fi
                if [ ! -n "$BIN" ]; then
                  BIN=$(mktemp /tmp/firmware-XXXXXX.bin)
                  trap "rm $BIN" SIGINT SIGABRT
                  ${pkgs.curl}/bin/curl -sL https://github.com/hall/little-buddy/releases/download/$VERSION/little-buddy-$VERSION-$LANGUAGE.bin -o $BIN
                fi

                # should correctly identify the pinebuds
                path=/dev/serial/by-id/usb-wch.cn_USB_Dual_Serial_0123456789-if
                for id in 02 00; do
                  # use the given file or a default
                  ${self.packages.${system}.bestool}/bin/bestool write-image --port $path$id $BIN 
                done
              '';
            };
            logs = inputs.utils.lib.mkApp {
              drv = pkgs.writeShellScriptBin "tts" ''
                if [ $1 == "left" ]; then
                  id=02
                elif [ $1 == "right" ]; then
                  id=00
                else
                  echo error: must pass either \"left\" or \"right\" as an argument
                  exit 1
                fi
                path=/dev/serial/by-id/usb-wch.cn_USB_Dual_Serial_0123456789-if
                ${pkgs.minicom}/bin/minicom -D $path$id -b 2000000
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
                ffmpeg
                xxd
              ];
              buildPhase = with pkgs; ''
                ${findutils}/bin/find ./config/res/spoken -maxdepth 1 -mindepth 1 -type d -exec \
                    ${bash}/bin/sh -c '${gnumake}/bin/make -j LANGUAGE=$(${coreutils}/bin/basename {})' \;
              '';
              installPhase = ''
                version=$(cat CHANGELOG.md | grep '^## \[[0-9]' | head -1 | cut -d "[" -f2 | cut -d "]" -f1)

                ${pkgs.util-linux}/bin/rename firmware ${name}-$version ./out/firmware-*.bin 
                mkdir -p $out
                mv ./out/*.bin $out/
              '';
            };
          };
          checks = {
            pre-commit = inputs.pre-commit.lib."${system}".run {
              src = ./.;
              hooks = {
                treefmt = {
                  name = "treefmt";
                  enable = true;
                  types = [ "file" ];
                  pass_filenames = true;
                  entry = "${pkgs.treefmt}/bin/treefmt";
                };
              };
            };
          };
          devShell = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit) shellHook;
            inputsFrom = [ self.packages.${system}.default ];
            buildInputs = with pkgs; [
              # formatters
              treefmt
              nixpkgs-fmt
              nodePackages.prettier
              clang
            ];
          };
        }
      );
}
