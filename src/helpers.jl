"""
    attenuations_intermediate_terms(latlon; kwargs...)
    attenuations_intermediate_terms(latlon, f; kwargs...)
    attenuations_intermediate_terms(latlon, f, p; kwargs...)

This function computes all the intermediate terms that can speed up the computation of the P618 attenuations.
The three different methods will produce progressively more intermediate terms (i.e. the outputs of this function) as some terms depend only on location, other also on frequency, and finally others also on the outage probability.

This function is useful when the troposheric attenuations (from P618) need to be computed multiple times for the same location, frequency and/or outage probability. Saving these terms and passing them as kwargs to the `attenuations` function can lead to up to 10 times faster computation of repeated calls.

## Arguments
- `latlon`: Object specifying the latitude and longitude of the location of interest, must be an object that can be converted to an instance of `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `f`: frequency (GHz) [Optional]
- `p`: outage probability (%) [Optional]

# Computed terms
- `Nwet`: Wet term surface refractivity (N-units)
- `hᵣ`: Rain height [Km] to be used for the computation.
- `alt`: Altitude [km] of the receiver. Defaults to `ItuRP1511.topographicheight(latlon)`
- `R001`: Annual rain rate [mm/h] exceeded 0.01% of the time.
- `γₒ`: Mean surface specific attenuation due to oxygen (dB/km) [Only returned if `f` is provided as input]
- `Ag_zenith`: Zenith gaseous attenuation (dB/km) at zenith (90° elevation) [Only returned if `f` and `p` are provided as input]
- `Ac_zenith`: Zenith cloud attenuation (dB/km) at zenith (90° elevation) [Only returned if `f` and `p` are provided as input]

!!! note "Overriding some inputs"
    All of the computed terms can be overridden by providing the intended value as keyword argument with the same name. 
    
    For simplicity, the two following terms also accept an alternative name when provided as keyword argument:
    - `h_r` for `hᵣ` (The Rain Height term [km])
    - `gamma_oxygen` for `γₒ` (The Mean Surface Specific Attenuation Due to Oxygen term [dB/km])

# Extended Help
## Example Use
The following snippet of code can be seen as a way to move some parts of the computation outside of hot loops. The example below will assume to compute attenuations from a specific location, and between the same location and multiple satellites at different elevation angles.

```julia
using ITUPropagationModels
gateway = LatLon(52.37, 4.89) # Amsterdam, The Netherlands
f = 30 # 30 GHz frequency

constant_terms = attenuations_intermediate_terms(gateway, f) # Compute the terms that stay constant for the specific location and assuming 30 GHz frequency

# We now assume that we are at a specific timestep, and we have a instantaneous fading realization corresponding to an outage probability of 1%.
p = 1 # 1% outage
current_timestep_terms = attenuations_intermediate_terms(gateway, f, p; constant_terms...) # Compute the terms that stay constant for the specific timestep, taking the terms not depending on the outage as inputs to speed up the additional computation

# We can now use the `current_timestep_terms` to speed up the elevation-dependent computation of attenuations for each specific satellite
for sat in satellites # This variable is not defined
    this_sat_attenuations = attenuations(gateway, f, sat.elevation, p; D = 1, current_timestep_terms...)
end
```
"""
function attenuations_intermediate_terms(latlon; Nwet = nothing, h_r = nothing, hᵣ = nothing, alt = nothing, R001 = nothing)
    Nwet = @something(Nwet, ItuRP453.wettermsurfacerefractivityannual_50(latlon))
    hᵣ = @something(hᵣ, h_r, ItuRP839.rainheightannual(latlon)) |> _tokm
    alt = @something(alt, altitude_from_location(latlon)) |> _tokm
    R001 = @something(R001, ItuRP837.rainfallrate001(latlon))
    return (; Nwet, hᵣ, alt, R001)
end

function attenuations_intermediate_terms(latlon, f; Nwet = nothing, h_r = nothing, hᵣ = nothing, alt = nothing, R001 = nothing, gamma_oxygen = nothing, γₒ = nothing)
    f = _toghz(f) |> Float64
    (; alt) = location_based = attenuations_intermediate_terms(latlon; Nwet, h_r, hᵣ, alt, R001)
    γₒ = @something γₒ gamma_oxygen let
        mean_vals = ItuRP2145.annual_surface_values(latlon; alt)
        P̄ = mean_vals.P
        T̄ = mean_vals.T
        ρ̄ = mean_vals.ρ
        ē = ρ̄ * T̄ / 216.7
        P̄d = P̄ - ē
        ItuRP676._gammaoxygen(f, T̄, P̄d, ρ̄).γₒ
    end
    return (; location_based..., γₒ)
end

function attenuations_intermediate_terms(latlon, f, p; Nwet = nothing, h_r = nothing, hᵣ = nothing, alt = nothing, R001 = nothing, gamma_oxygen = nothing, γₒ = nothing, Ac_zenith = nothing, Ag_zenith = nothing)
    f = _toghz(f) |> Float64
    (; γₒ, alt) = location_and_frequency_based = attenuations_intermediate_terms(latlon, f; Nwet, h_r, hᵣ, alt, R001, gamma_oxygen, γₒ)
    p_to_use = max(5, p)
    Ac_zenith = @something Ac_zenith ItuRP840.cloudattenuation(latlon, f, 90, p_to_use)
    Ag_zenith = @something Ag_zenith ItuRP676.gaseousattenuation(latlon, f, 90, p_to_use; alt, γₒ)
    return (; location_and_frequency_based..., Ag_zenith, Ac_zenith)
end

attenuations_intermediate_terms(lat::Number, lon::Number, args::Vararg{Any, N}; kwargs...) where N = attenuations_intermediate_terms(LatLon(lat, lon), args...; kwargs...)