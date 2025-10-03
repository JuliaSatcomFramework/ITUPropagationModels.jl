# Main Functions

!!! note
    All functions support as input `Unitful.Quantity` values for frequency (e.g. `Hz`), angles (`°` or `rad`) and length (e.g. `m`, but only for values which are expected in `km` like the location altitude or the rain height `hᵣ`)

The primary interface for calculating atmospheric attenuations.

## Primary Function

```@docs
attenuations
attenuations_intermediate_terms
```


# ITU-R P.453 - Refractivity

```@docs
ITUPropagationModels.ItuRP453.wettermsurfacerefractivityannual
ITUPropagationModels.ItuRP453.wettermsurfacerefractivityannual_50
```

# ITU-R P.618 - Rain Attenuation and Scintillation

```@docs
ITUPropagationModels.ItuRP618.rainattenuation
ITUPropagationModels.ItuRP618.scintillationattenuation
```

# ITU-R P.676 - Gaseous Attenuation

```@docs
ITUPropagationModels.ItuRP676.gaseousattenuation
```

# ITU-R P.835 - Standard Atmospheres

```@docs
ITUPropagationModels.ItuRP835.standardtemperature
ITUPropagationModels.ItuRP835.standardpressure
ITUPropagationModels.ItuRP835.standardwatervapourdensity
```

# ITU-R P.837 - Rainfall Rate

```@docs
ITUPropagationModels.ItuRP837.rainfallrate001
```

# ITU-R P.838 - Rain Specific Attenuation

```@docs
ITUPropagationModels.ItuRP838.rainspecificattenuation
```

# ITU-R P.839 - Rain Height

```@docs
ITUPropagationModels.ItuRP839.rainheightannual
ITUPropagationModels.ItuRP839.isothermheight
```

# ITU-R P.840 - Cloud and Fog Attenuation

```@docs
ITUPropagationModels.ItuRP840.cloudattenuation
ITUPropagationModels.ItuRP840.liquidwatercontent
```

# ITU-R P.1511 - Topographic Data

```@docs
ITUPropagationModels.ItuRP1511.topographicheight
```

# ITU-R P.2145 - Surface Meteorological Data

```@docs
ITUPropagationModels.ItuRP2145.surfacetemperatureannual
ITUPropagationModels.ItuRP2145.surfacewatervapourdensityannual
ITUPropagationModels.ItuRP2145.surfacepressureannual
ITUPropagationModels.ItuRP2145.surfacewatervapourcontentannual
ITUPropagationModels.ItuRP2145.annual_surface_values
```