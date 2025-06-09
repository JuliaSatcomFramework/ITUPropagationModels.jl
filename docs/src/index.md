# ITUPropagationModels.jl

A Julia implementation of ITU-R Recommendations for satellite communication link predictions, covering atmospheric propagation effects including cloud, gaseous, rain, and scintillation attenuations.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl")
```

## Basic Usage

```julia
using ITUPropagationModels

# Calculate atmospheric attenuation for a satellite link
latlon = LatLon(45, 10)  # Location coordinates
frequency = 20.0       # GHz
elevation = 30.0       # degrees
probability = 0.01     # % exceedance

# Get all atmospheric attenuations, assume 1m diameter (only used for scintillation attenuation)
result = attenuations(latlon, frequency, elevation, probability; D = 1)

println("Total attenuation: $(result.total) dB")
```

## Documentation

See the **[API Reference](api/main.md)** for complete function documentation. 