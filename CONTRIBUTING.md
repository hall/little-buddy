# CONTRIBUTING

This project uses the [nix](https://nixos.org/download.html) package manager.

> **NOTE**: until they're no longer experimental, you'll need to [enable flakes](https://nixos.wiki/wiki/Flakes#Enable_flakes)

## build

Enter a development environment with

```sh
nix develop  # or use direnv or do the setup yourself, whatever
```

Build the project with

```sh
make -j
```

The compiled firmware will be at `./out/firmware.bin`.

## language

Audio notification sounds are generated with [translate-shell](https://github.com/soimort/translate-shell) by running

```sh
nix run '.#tts' <lang>
```

> **NOTE**: for reproducibility, these files should be committed to the repo (doing so will automatically include them in the next release)

The default language is English but can be changed by passing a [2-digit language code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) to `make`

```sh
make -j LANG=fr
```

## flash

Flash both earbuds:

    for i in 0 1; do bestool write-image --port /dev/ttyACM$i result/*.bin; done

## logs

View logs over the serial port with

    minicom -D /dev/ttyACM0 -b 2000000

## release

Move the "Unreleased" section in [`CHANGELOG.md`](./CHANGELOG.md) to a new version.
Once pushed the [`main.yml`](./.github/workflows/main.yml) workflow will create a new release.
