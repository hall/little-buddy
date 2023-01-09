# Little Buddy

Firmware for the [PineBuds Pro](https://wiki.pine64.org/wiki/PineBuds_Pro). Hopefully.

> **WARNING**: use at your own risk; this is currently worse than the factory default

## install

Download the latest [release](https://github.com/hall/little-buddy/releases).

Flash both earbuds with [`bestool`](https://github.com/Ralim/bestool):

    bestool write-image --port /dev/ttyACM0 little-buddy-*.bin
    bestool write-image --port /dev/ttyACM1 little-buddy-*.bin

> **NOTE**: if you have [nix](https://nixos.org/download.html) installed, you can use `nix run 'github:hall/little-buddy#bestool'` instead of building and installing `bestool` yourself

## attribution

Thus far, I've written almost none of this.
All credit goes to the original authors.

### name

The upstream tarball was named "Little Whale" so I combined that with the device name :shrug:
