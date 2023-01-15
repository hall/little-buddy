# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2023-01-15

### Changed

- shift volume scale so the lower end is quieter

## [0.1.1] - 2023-01-15

This release welcomes a handful of common languages.
See the `README.md` file for details.

### Added

- support for different notification languages

## [0.1.0] - 2023-01-09

This release pulls in changes from [OpenPineBuds](https://github.com/pine64/OpenPineBuds).

### Added

- hold (~5s) button while in the case to force a reboot (so it can be programmed)
- audio controls using the touch button on the buds (see README.md)

### Changed

- turn off LEDs and enter low-power state when battery is fully charged
- use internal resistor to pick left/right instead of TWS master/slave pairing
- pressing the button while in the case no longer triggers DFU mode
- debugging baud rate raised to 2,000,000 to match stock firmware

### Fixed

- putting either bud into the case correctly switches to the other bud
- don't register as an HID keyboard

## [0.0.0] - 2023-01-09

### Added

- init from upstream SDK release on Pine64's wiki
