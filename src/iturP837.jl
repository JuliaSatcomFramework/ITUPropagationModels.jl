module ItuRP837

#=
Rainfall rate statistics with a 1-min integration time are required for the prediction of rain attenuation
 in terrestrial links (e.g. Recommendation ITU-R P.530) and Earth-space links (e.g. Recommendation ITU-R P.618).

When reliable long-term local rainfall rate data is not available, Annex 1 of this Recommendation provides
 a rainfall rate prediction method for the prediction of rainfall rate statistics with a 1-min integration time
 This prediction method is based on: a) total monthly rainfall data generated from the GPCC Climatology (V 2015) database
 over land and from the European Centre for Medium-Range Weather Forecast (ECMWF) ERA Interim re-analysis database
 over water, and b) monthly mean surface temperature data in Recommendation ITU-R P.1510.

When reliable long-term local rainfall rate data is available with integration times greater than 1-min,
 Annex 2 of this Recommendation provides a method for converting rainfall rate statistics with integration
 times that exceed 1-min to rainfall rate statistics with a 1-min integration time.
=#

using ..ITUPropagationModels: ITUPropagationModels, LatLon, ItuRVersion, tolatlon, Q, bisect
using ..ItuRP1144: ItuRP1144, SquareGridData
using ..ItuRP1510: ItuRP1510
using Artifacts

const version = ItuRVersion("ITU-R", "P.837", 7, "(06/2017)")

# Exports and constructor with separate latitude and longitude arguments
for name in (:rainfallrate001, :rainprobability, :rainfallrate)
    @eval $name(lat::Number, lon::Number, args...; kwargs...) = $name(LatLon(lat, lon), args...; kwargs...)
    @eval export $name
end
# A (Number, Real) call is ambiguous between the separate lat/lon wrapper above and `rainfallrate(latlon, p)`; this method resolves it with a clear error
rainfallrate(::Number, ::Real) = throw(ArgumentError("This method signature is not supported by ItuRP837.rainfallrate, you probably forgot to provide one argument.\nRemember that the first input to this function is either a single object representing the Lat/Lon location of interest or two separate numbers representing the latitude and longitude."))

#region initialization

const δlat = 0.125
const δlon = 0.125
const latrange = range(-90, 90, step=δlat)
const lonrange = range(-180, 180, step=δlon)
const datasize = (length(latrange), length(lonrange))

const SGD_TYPE = let
    T = Float64
    R = typeof(latrange)
    SquareGridData{T, R, String}
end

@kwdef mutable struct RainfallRate001
    itp::Union{SGD_TYPE, Nothing} = nothing
end

const R001_DATA = RainfallRate001()

function initialize!()
    data = read!(joinpath(artifact"p837_R001", "R001.bin"), zeros(datasize))
    R001_DATA.itp = SquareGridData(latrange, lonrange, data, "Rainfall rate exceeded 0.01% of the year")
    return nothing
end

# Monthly total rainfall maps live on a grid padded by half a cell beyond the poles and the antimeridian
const MT_latrange = range(-90.125, 90.125, step=0.25)
const MT_lonrange = range(-180.125, 180.125, step=0.25)
const MT_datasize = (length(MT_latrange), length(MT_lonrange))
const MT_SGD_TYPE = SquareGridData{Float64, typeof(MT_latrange), String}

@kwdef mutable struct MonthlyRainfall
    itps::Union{NTuple{12, MT_SGD_TYPE}, Nothing} = nothing
end

const MT_DATA = MonthlyRainfall()

function initialize_monthly!()
    dir = artifact"p837_monthly"
    MT_DATA.itps = ntuple(Val(12)) do m
        data = read!(joinpath(dir, "MT_Month$(lpad(m, 2, '0')).bin"), zeros(MT_datasize))
        SquareGridData(MT_latrange, MT_lonrange, data, "Monthly mean total rainfall (mm), month $m")
    end
    return nothing
end

#endregion initialization

"""
    rainfallrate001(latlon)
    rainfallrate001(lat::Number, lon::Number)

Computes rainfall rate exceeded 0.01% via bi-linear interpolation as described in Annex 1.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.

# Return
- `R::Float64`: annual rainfall rate exceeded 0.01%
"""
function rainfallrate001(latlon)
    latlon = tolatlon(latlon)
    itp = @something(R001_DATA.itp, let
        initialize!()
        R001_DATA.itp
    end)::SGD_TYPE
    return itp(latlon)
end

const DAYS_IN_MONTH = (31.0, 28.25, 31.0, 30.0, 31.0, 30.0, 31.0, 31.0, 30.0, 31.0, 30.0, 31.0)

# Steps 1-3 of Annex 1: monthly rainfall, temperature, conditional rain rate and probability of rain
function _rainprobability(latlon::LatLon)
    itps = @something(MT_DATA.itps, let
        initialize_monthly!()
        MT_DATA.itps
    end)::NTuple{12, MT_SGD_TYPE}
    MT = ntuple(m -> itps[m](latlon), Val(12))
    T = ntuple(m -> ItuRP1510.surfacemeantemperature(latlon, m), Val(12))
    r₀ = ntuple(Val(12)) do m
        t = T[m] - 273.15
        t >= 0 ? 0.5874 * exp(0.0883 * t) : 0.5874
    end
    P0m₀ = ntuple(m -> 100 * MT[m] / (24 * DAYS_IN_MONTH[m] * r₀[m]), Val(12))
    # A monthly probability of rain above 70 % is capped there and the conditional rain rate rescaled to conserve the monthly total
    r = ntuple(m -> P0m₀[m] > 70 ? 100 / 70 * MT[m] / (24 * DAYS_IN_MONTH[m]) : r₀[m], Val(12))
    P0m = ntuple(m -> min(P0m₀[m], 70.0), Val(12))
    P0 = sum(map(*, DAYS_IN_MONTH, P0m)) / 365.25
    return (; MT, T, r, P0m, P0)
end

"""
    rainprobability(latlon)
    rainprobability(lat::Number, lon::Number)

Annual probability of rain ``P_0`` (%) at the given location, following steps 1 to 3 of Annex 1 of ITU-R P.837-7, from the monthly total rainfall maps of this Recommendation and the monthly mean surface temperature of ITU-R P.1510.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.

# Return
- `P0::Float64`: annual probability of rain (%)
"""
rainprobability(latlon) = _rainprobability(tolatlon(latlon)).P0

# Percentage of an average year during which the 1-min rain rate exceeds R (Annex 1, step 4)
function _exceedanceprobability(R::Real, r::NTuple{12, <:Real}, P0m::NTuple{12, <:Real})
    acc = 0.0
    for m in eachindex(r, P0m)
        acc += DAYS_IN_MONTH[m] * P0m[m] * Q((log(R) + 0.7938 - log(r[m])) / 1.26)
    end
    return acc / 365.25
end

"""
    rainfallrate(latlon, p)
    rainfallrate(lat::Number, lon::Number, p)

Rainfall rate ``R_p`` (mm/h) with 1-min integration time exceeded for `p` % of an average year, following Annex 1 of ITU-R P.837-7. For `p == 0.01` the pre-computed map of [`rainfallrate001`](@ref) is returned; when `p` exceeds the annual probability of rain the result is `0.0`.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p`: exceedance probability (%)

# Return
- `Rp::Float64`: rainfall rate exceeded for `p` % of the time (mm/h)
"""
function rainfallrate(latlon, p::Real)
    latlon = tolatlon(latlon)
    0 < p <= 100 || throw(ArgumentError("p must be an exceedance probability in percent within (0, 100], got $p"))
    p == 0.01 && return rainfallrate001(latlon)
    (; r, P0m, P0) = _rainprobability(latlon)
    p > P0 && return 0.0
    # The exceedance probability is monotonically decreasing in R; bisect on log R for uniform relative precision
    lnR = bisect(log(1e-10), log(1000.0); xtol = 1e-12) do x
        _exceedanceprobability(exp(x), r, P0m) - p
    end
    return exp(lnR)
end

end # module ItuRP837
