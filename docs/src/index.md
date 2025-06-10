# ITUPropagationModels.jl

A Julia implementation of ITU-R Recommendations for satellite communication link predictions, covering atmospheric propagation effects including cloud, gaseous, rain, and scintillation attenuations.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl")
```

## Basic Usage

```@example
using ITUPropagationModels

# Calculate atmospheric attenuation for a satellite link
latlon = LatLon(45, 10)  # Location coordinates
frequency = 20.0       # GHz
elevation = 30.0       # degrees
probability = 0.01     # % exceedance

# Get all atmospheric attenuations, assume 1m diameter (only used for scintillation attenuation)
attenuations(latlon, frequency, elevation, probability; D = 1)
```

## Custom location types
It is possible to use the various functions of this package on custom types representing locations on earth by defining an appropriate method for `Base.convert` as shown in the example below.

Additionally, in case your custom type also contains altitude information, it is possible to provide this information to the package function by adding a custom method to the following function
```@docs
ITUPropagationModels.altitude_from_location
```

Here is an example of defining a custom type and making it compatible with the functions from this package:

```@example
using ITUPropagationModels

# We create a custom struct that also stores location (in m) and lat/lon in radians
struct LLA
    lat::Float64
    lon::Float64
    alt::Float64
end
# Define a convert method to convert to LatLon
Base.convert(::Type{LatLon}, lla::LLA) = LatLon(lla.lat |> rad2deg, lla.lon |> rad2deg)
# Define a method to extract the altitude from the custom type, remembering the returned altitude MUST be in km
ITUPropagationModels.altitude_from_location(lla::LLA) = lla.alt / 1e3

# We test with our custom instance of a type
lla = LLA(deg2rad(30), deg2rad(45), 1200)

custom = attenuations(lla, 30, 20, .5; D = 1)
equivalent = attenuations(LatLon(30, 45), 30, 20, .5; D = 1, alt = 1.2)
println(custom)
println(equivalent)
```

## Documentation

See the **[API Reference](api/main.md)** for complete function documentation. 