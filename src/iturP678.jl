module ItuRP678

#=
Inter-annual variability of rainfall rate and rain attenuation statistics around their long-term CCDF (Annex 2), and the risk that a yearly exceedance probability is not met (Annex 3).
Annex 1 (year-to-year variation of the worst-month time fraction of excess) is published as a figure only and is not implemented.
=#

using ..ITUPropagationModels: ITUPropagationModels, LatLon, ItuRVersion, tolatlon, Q, SUPPRESS_WARNINGS
using ..ItuRP1144: SquareGridData
using Artifacts

const version = ItuRVersion("ITU-R", "P.678", 3, "(07/2015)")

# Exports and constructor with separate latitude and longitude arguments
for name in (:climaticratio, :interannualvariance, :riskofexceedance)
    @eval $name(lat::Number, lon::Number, args...; kwargs...) = $name(LatLon(lat, lon), args...; kwargs...)
    @eval export $name
end
# Two or three bare numbers match the separate lat/lon wrapper above and would silently read a probability as a longitude; these methods give a clear error instead
const MISSING_ARGUMENT = "This method signature is not supported, you probably forgot to provide one argument.\nRemember that the first input to this function is either a single object representing the Lat/Lon location of interest or two separate numbers representing the latitude and longitude."
interannualvariance(::Number, ::Real; kwargs...) = throw(ArgumentError("ItuRP678.interannualvariance: " * MISSING_ARGUMENT))
riskofexceedance(::Number, ::Real, ::Real; kwargs...) = throw(ArgumentError("ItuRP678.riskofexceedance: " * MISSING_ARGUMENT))

#region initialization

const δ = 0.5
# The ITU map is cell-centred (first row -89.75°, first column -179.75°). It is padded by one row at each pole and one column beyond each side of the antimeridian so that bilinear interpolation covers the whole sphere: the pole rows repeat the nearest ring, the extra columns wrap around
const latrange = range(-90.25, 90.25, step=δ)
const lonrange = range(-180.25, 180.25, step=δ)
const rawsize = (length(latrange) - 2, length(lonrange) - 2)

const SGD_TYPE = SquareGridData{Float64, typeof(latrange), String}

@kwdef mutable struct ClimaticRatioData
    itp::Union{SGD_TYPE, Nothing} = nothing
end

const DATA = ClimaticRatioData()

function initialize!()
    raw = read!(joinpath(artifact"p678", "CLIMATIC_RATIO.bin"), zeros(rawsize))
    rows = vcat(raw[1:1, :], raw, raw[end:end, :])
    padded = hcat(rows[:, end], rows, rows[:, 1])
    DATA.itp = SquareGridData(latrange, lonrange, padded, "Climatic ratio")
    return nothing
end

#endregion initialization

#region internal functions

const N_MINUTES = 525960 # minutes in an average year, equation 3
const Δt = 60 # s, equation 3

# Variance of estimation, Annex 2 equations 2 to 5. The autocorrelation terms decrease monotonically with i, so the sum stops once they fall below machine precision
function _varianceofestimation(p::Real)
    p * (1 - p) == 0 && return 0.0
    a = 0.0265
    b = -0.0396 * log(p) + 0.286
    C = 1.0
    for i in 1:(N_MINUTES - 1)
        c = exp(-a * (i * Δt)^b)
        c < eps() && break
        C += 2c
    end
    return p * (1 - p) * C / N_MINUTES
end

_checkprobability(p, name) = 0 <= p <= 1 || throw(ArgumentError("The exceedance probability $name must be a fraction within [0, 1], got $p"))

#endregion internal functions

"""
    climaticratio(latlon)
    climaticratio(lat::Number, lon::Number)

Climatic ratio ``r_c`` at the given location, bi-linearly interpolated from the digital map of ITU-R P.678-3 (Annex 2, steps 3 and 4).

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.

# Return
- `rc::Float64`: climatic ratio (dimensionless)
"""
function climaticratio(latlon)
    latlon = tolatlon(latlon)
    itp = @something(DATA.itp, let
        initialize!()
        DATA.itp
    end)::SGD_TYPE
    return itp(latlon)
end

"""
    interannualvariance(latlon, p; warn, sigma2E)
    interannualvariance(lat::Number, lon::Number, p; warn, sigma2E)

Inter-annual variance of the exceedance probability `p` of a rainfall rate or rain attenuation statistic at the given location, following Annex 2 of ITU-R P.678-3. The yearly exceedance probability is normally distributed around the long-term `p` with this variance.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p`: long-term exceedance probability as a fraction, `0 ≤ p ≤ 1`. The method is applicable for `0.0001 ≤ p ≤ 0.02`; a warning is issued outside this range unless `warn = false`. Note that `p` is a fraction here, unlike the percentages taken by `ItuRP618.rainattenuation` and `ItuRP837.rainfallrate`.
- `warn`: Whether to warn if `p` is outside the supported range. Defaults to `!SUPPRESS_WARNINGS[]`.
- `sigma2E`: variance of estimation (equation 5). Computed from `p` by default; it depends on `p` only, so pass a precomputed value when evaluating many locations at the same `p` (the default costs up to a few hundred thousand exponentials per call at `p` near 0.02).

# Return
A `NamedTuple` with fields
- `sigma2`: total inter-annual variance (equation 1)
- `sigma2C`: inter-annual climatic variance (equation 6)
- `sigma2E`: variance of estimation (equation 5)

When the long-term statistic is a predicted CCDF (for example the rain attenuation of `ItuRP618.rainattenuation`) rather than a measured one, Annex 2 (equation 7) adds the error of the prediction, ``σ²_M``, to the returned `sigma2`; that term depends on the prediction method and is not computed here.
"""
function interannualvariance(latlon, p; warn=!SUPPRESS_WARNINGS[], sigma2E=_varianceofestimation(p))
    _checkprobability(p, "p")
    1e-4 <= p <= 2e-2 || !warn || @noinline(@warn("ItuRP678.interannualvariance is only applicable for exceedance probabilities between 0.01% and 2% (0.0001 ≤ p ≤ 0.02).\nThe given p = $p is outside this range so results may be inaccurate."))
    rc = climaticratio(latlon)
    sigma2C = (rc * p)^2
    sigma2 = sigma2C + sigma2E
    return (; sigma2, sigma2C, sigma2E)
end

"""
    riskofexceedance(latlon, p, pr; warn, sigma2E)
    riskofexceedance(lat::Number, lon::Number, p, pr; warn, sigma2E)

Risk, as a probability, that the yearly exceedance probability of a fixed rain attenuation is above `pr`, when its long-term exceedance probability is `p` (Annex 3 of ITU-R P.678-3, equation 8). `pr == p` gives 0.5.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p`: long-term exceedance probability as a fraction, `0 ≤ p ≤ 1` (see [`interannualvariance`](@ref) for the applicable range). Note that `p` is a fraction here, unlike the percentages taken by `ItuRP618.rainattenuation` and `ItuRP837.rainfallrate`.
- `pr`: yearly exceedance probability as a fraction, `0 ≤ pr ≤ 1`
- `warn`, `sigma2E`: keywords forwarded to [`interannualvariance`](@ref)

# Return
- `risk::Float64`: probability that the yearly exceedance probability is above `pr`
"""
function riskofexceedance(latlon, p, pr; kwargs...)
    _checkprobability(pr, "pr")
    pr == p && return 0.5
    (; sigma2) = interannualvariance(latlon, p; kwargs...)
    return Q((pr - p) / sqrt(sigma2))
end

end # module ItuRP678
