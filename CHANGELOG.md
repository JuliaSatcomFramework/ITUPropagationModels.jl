# Changelog

This file contains the changelog for the ItuRPropagation package. It follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

## Unreleased

### Added
- `ItuRP840.lognormalparameters` and `ItuRP840.cloudattenuation_lognormal` implementing the log-normal approximation to the slant path cloud attenuation of Section 3.3 of ITU-R P.840-9.
- The `p840_annual` artifact now also contains the `mL`, `sL` and `PL` maps of Part 14 of ITU-R P.840-9; its release asset is now `p840_annual.tar.gz` (the previous asset stays available for older package versions).

## 1.2.0 - 2026-09-23

### Added
- `ItuRP837.rainprobability` (annual probability of rain) and `ItuRP837.rainfallrate` (rainfall rate at any exceedance probability) implementing Annex 1 of ITU-R P.837-7 in full.
- New `ItuRP1510` module with `surfacemeantemperature` (annual and monthly) from ITU-R P.1510-1.
- New artifacts `p1510` and `p837_monthly`.
- `SpecialFunctions` is now a dependency.
- The artifact scripts download from the ITU with browser headers (`download_itu`); the P.837-7 archive is now fetched from its superseded-edition URL since P.837-8 was published.

## 1.1.1 - 2025-10-07
### Fixed
- Fixed the computation of the intermediate terms for the `gaseousattenuation` function when the location is provided as a custom type.

## 1.1.0 - 2025-10-07
### Added
- Added a new `attenuations_intermediate_terms` function to compute the intermediate terms for the `attenuations` function that only depend on the location of the ground station and, optionally, on the frequency and/or outage probability of the link.

## 1.0.2 - 2025-10-03

### Fixed
- Fixed wrong order of NamedTuple returned by `attenuations` function and improve method inference (to remove allocations).
- Fixed the docstring of `attenuations` function referring to `618-13` instead of `618-14`.

## 1.0.1 - 2025-06-10

### Added
- Added handling of `p > 50` and `p < 0.001` within the `attenuations` function. Current behavior is to _cap_ outage to a lower value of `0.001` and to return `0.0` for each attenuations when `p > 50`. This behavior can be changed via keyword arguments. Check extended help of `attenuations` for details.

## 1.0.0 - 2025-06-09

First release of `ITUPropagationModels`, see https://github.com/JuliaSatcomFramework/ItuRPropagation.jl for more insights on PRs and changes on the original repository before the package names was changed.