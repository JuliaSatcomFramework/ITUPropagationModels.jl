"""
    attenuations_intermediate_terms(latlon, f; kwargs...)

This function computes all the intermediate terms that can speed up the computation of the P618 attenuations and that only depend on the location (i.e. Latitude and Longitude) and the frequency.

This function is useful when the troposheri attenuations (from P618) need to be computed multiple times for the same location and frequency as saving this terms and using them by passing them to the `attenuations` function is more than twice as fast.

## Arguments
- `latlon`: Object specifying the latitude and longitude of the location of interest, must be an object that can be converted to an instance of `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `f`: frequency (GHz)

# Computed terms
- `Nwet`: Wet term surface refractivity (N-units)
- `hᵣ`: Rain height [Km] to be used for the computation.
- `alt`: Altitude [km] of the receiver. Defaults to `ItuRP1511.topographicheight(latlon)`
- `R001`: Annual rain rate [mm/h] exceeded 0.01% of the time.
- `γₒ`: Mean surface specific attenuation due to oxygen (dB/km)

!!! note "Overriding some inputs"
    All of the computed terms can be overridden by providing the intended value as keyword argument with the same name. 
    
    For simplicity, the two following terms also accept an alternative name when provided as keyword argument:
    - `h_r` for `hᵣ` (The Rain Height term [km])
    - `gamma_oxygen` for `γₒ` (The Mean Surface Specific Attenuation Due to Oxygen term [dB/km])
"""
function attenuations_intermediate_terms(latlon, f; Nwet = nothing, h_r = nothing, hᵣ = nothing, alt = nothing, R001 = nothing, gamma_oxygen = nothing, γₒ = nothing)
    Nwet = @something(Nwet, ItuRP453.wettermsurfacerefractivityannual_50(latlon))
    hᵣ = @something(hᵣ, h_r, ItuRP839.rainheightannual(latlon)) |> _tokm
    alt = @something(alt, altitude_from_location(latlon)) |> _tokm
    R001 = @something(R001, ItuRP837.rainfallrate001(latlon))
    mean_vals = ItuRP2145.annual_surface_values(latlon; alt)
    P̄ = mean_vals.P
    T̄ = mean_vals.T
    ρ̄ = mean_vals.ρ
    γₒ = @something γₒ gamma_oxygen let
        ē = ρ̄ * T̄ / 216.7
        P̄d = P̄ - ē
        ItuRP676._gammaoxygen(f, T̄, P̄d, ρ̄).γₒ
    end
    return (; Nwet, hᵣ, alt, R001, γₒ)
end

attenuations_intermediate_terms(lat::Number, lon::Number, f; kwargs...) = attenuations_intermediate_terms(LatLon(lat, lon), f; kwargs...)