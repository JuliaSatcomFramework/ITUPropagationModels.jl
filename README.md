# ITUPropagationModels
[![Docs Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliasatcomframework.github.io/ITUPropagationModels.jl/stable)
[![Docs Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliasatcomframework.github.io/ITUPropagationModels.jl/dev)
[![Build Status](https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSatcomFramework/ITUPropagationModels.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaSatcomFramework/ITUPropagationModels.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

A Julia implementation of some of the ITU-Recommendations for space links covering cloud, gaseous, rain, and scintillation attenuations.

> [!NOTE]
> This repository started as a fork of https://github.com/HillaryKchao/ItuRPropagation.jl mostly to improve performance of the code and avoid storing assets directly in the git history. The original fork is still hosted in a separate repository at https://github.com/JuliaSatcomFramework/ItuRPropagation.jl but I decided to change name and UUID of the package due to significant breaking changes in June 2025 and the rewrite in git history that this repo went through to avoid downloading >100Mb of data for each `git clone`

## Installation
This fork is not currently registered in the general registry (while the original repository is).
To add it, you have then to explicitly point to this repository with the folloing command in the `Pkg` repl mode
```
add https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl
```
You can check if installation was successful by exiting the package manager and using
```
using ITUPropagationModels
```

## ITU-R Recommendations
The following ITU-R Recommendations are implemented at least in part:
*   **ITU-R P.453-14:** The radio refractive index: its formula and refractivity data
*   **ITU-R P.618-14:** Propagation data and prediction methods required for the design of Earth-space telecommunication systems
*   **ITU-R P.676-13:** Attenuation by atmospheric gases
*   **ITU-R P.835-7:** Reference Standard Atmospheres
*   **ITU-R P.837-7:** Characteristics of precipitation for propagation modelling
*   **ITU-R P.838-8:** Specific attenuation model for rain for use in prediction methods
*   **ITU-R P.839-4:** Rain height model for prediction methods.
*   **ITU-R P.840-9:** Attenuation due to clouds and fog 
*   **ITU-R P.1144-12** Interpolations methods for other ITU-R Recommendations
*   **ITU-R P.1511-3:** Topography for Earth-to-space propagation modelling
*   **ITU-R P.2145-0:** Digital maps related to the calculation of gaseous attenuation and related effects

The auxiliary data required by some of the above recommendations is stored into artifacts automatically generated in CI using the scripts located in the `artifacts_scripts` folder, and stored as assets of the [Artifacts Release](https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl/releases/tag/artifacts_releases)

##  Validation
This implementation has been validated using the [ITU Validation examples (rev 8.3.0)](https://www.itu.int/en/ITU-R/study-groups/rsg3/ionotropospheric/CG-3M3J-13-ValEx-Rev8.3.0.xlsx).
