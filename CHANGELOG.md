# Changelog

This file contains the changelog for the ItuRPropagation package. It follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Unreleased

## 1.0.2 - 2025-10-03

### Fixed
- Fixed wrong order of NamedTuple returned by `attenuations` function and improve method inference (to remove allocations).
- Fixed the docstring of `attenuations` function referring to `618-13` instead of `618-14`.

## 1.0.1 - 2025-06-10

### Added
- Added handling of `p > 50` and `p < 0.001` within the `attenuations` function. Current behavior is to _cap_ outage to a lower value of `0.001` and to return `0.0` for each attenuations when `p > 50`. This behavior can be changed via keyword arguments. Check extended help of `attenuations` for details.

## 1.0.0 - 2025-06-09

First release of `ITUPropagationModels`, see https://github.com/JuliaSatcomFramework/ItuRPropagation.jl for more insights on PRs and changes on the original repository before the package names was changed.