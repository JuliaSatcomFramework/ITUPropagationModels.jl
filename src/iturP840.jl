module ItuRP840

#=
This Recommendation provides methods to predict the attenuation due to clouds and fog on Earth-space paths.
=#

using ..ITUPropagationModels: ITUPropagationModels, LatLon, ItuRVersion, tolatlon, _tokm, _todeg, _toghz, SUPPRESS_WARNINGS, Qinv
using ..ItuRP1144: ItuRP1144, AbstractSquareGridITP, SquareGridData, SquareGridStatisticalData
using Artifacts: Artifacts, @artifact_str

const version = ItuRVersion("ITU-R", "P.840", 9, "(08/2023)")

# Exports and constructor with separate latitude and longitude arguments
for name in (:liquidwatercontent, :cloudattenuation, :lognormalparameters, :cloudattenuation_lognormal)
    @eval $name(lat::Number, lon::Number, args...; kwargs...) = $name(LatLon(lat, lon), args...; kwargs...)
    @eval export $name
end

#region initialization

const δlat = 0.25
const δlon = 0.25
const latrange = range(-90, 90, step=δlat)
const lonrange = range(-180, 180, step=δlon)
const datasize = (length(latrange), length(lonrange))

# exceedance probabilities
const psannual = [0.01, 0.02, 0.03, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 3, 5, 10, 20, 30, 50, 60, 70, 80, 90, 95, 99]

# exceedance probability values for reading files
const filespsannual = ["001", "002", "003", "005", "01", "02", "03", "05", "1", "2", "3", "5", "10", "20", "30", "50", "60", "70", "80", "90", "95", "99"]

const SGD_TYPE = let
    T = Float64
    R = typeof(latrange)
    SquareGridData{T, R, String}
end

# This will hold the mean and annual ccdf data of integrated liquid water content for computation of the cloud attenuation, and the parameters (mL, sL, PL) of its log-normal approximation. The underlying data is already a interpolator that will use bilinear interpolation to find the value at the given location
@kwdef mutable struct LiquidContentData
    ccdf::Union{Nothing, SquareGridStatisticalData{SGD_TYPE}} = nothing
    mean::Union{Nothing, SGD_TYPE} = nothing
    lognormal::Union{Nothing, NTuple{3, SGD_TYPE}} = nothing
end

const ANNUAL_DATA = LiquidContentData()

function initialize!()
    isnothing(ANNUAL_DATA.mean) || return nothing
    @info "P840: Loading annual data of Integrated Liquid Water Content"
    Lmean = read!(artifact"p840_annual/L_mean.bin", zeros(datasize))
    ANNUAL_DATA.mean = SquareGridData(latrange, lonrange, Lmean, "Mean Integrated Liquid Water Content")
    items = map(zip(psannual, filespsannual)) do (p, suffix)
        data = read!(joinpath(artifact"p840_annual", "L_$(suffix).bin"), zeros(datasize))
        name = "Integrated Liquid Water Content at $p% exceedance probability"
        SquareGridData(latrange, lonrange, data, name)
    end
    ANNUAL_DATA.ccdf = SquareGridStatisticalData(psannual, items)
    return nothing
end

function initialize_lognormal!()
    isnothing(ANNUAL_DATA.lognormal) || return nothing
    @info "P840: Loading the log-normal approximation parameters of the Integrated Liquid Water Content"
    dir = artifact"p840_annual"
    load(name, id) = SquareGridData(latrange, lonrange, read!(joinpath(dir, name), zeros(datasize)), id)
    ANNUAL_DATA.lognormal = (
        load("mL.bin", "Log-normal mean parameter of the Integrated Liquid Water Content"),
        load("sL.bin", "Log-normal standard deviation parameter of the Integrated Liquid Water Content"),
        load("PL.bin", "Probability of cloud (%)"),
    )
    return nothing
end

#endregion initialization

#region internal functions

"""
    _Kₗ(f::Real, T::Real)

Computes cloud specific attenuation coefficient based on Section 2 (Equation 2). 
    
# Arguments
- `f::Real`: frequency (GHz)
- `T::Real`: temperature (°C)

# Return
- `K::Real`: attenuation coefficient ((dB/km)/(g/m^3))
"""
function _Kₗ( 
    f::Real,
    T::Real=273.75,
)
    coeff = 300 / T - 1 # Term repeated in many places
    ϵ₀ = 77.66 + 103.3 * coeff     # equation 6
    ϵ₁ = 0.0671 * ϵ₀     # equation 7
    ϵ₂ = 3.52     # equation 8
    fₚ = 20.2 - 146 * coeff + 316 * coeff^2     # equation 9
    fₛ = 39.8 * fₚ     # equation 11

    rfₚ = f / fₚ
    rfₛ = f / fₛ
    # equation 4
    ϵ′′ = (
        ((f * (ϵ₀ - ϵ₁)) / (fₚ * (1 + rfₚ^2)))
        +
        ((f * (ϵ₁ - ϵ₂)) / (fₛ * (1 + rfₛ^2)))
    )

    # equation 5
    ϵ′ = (
        (ϵ₀ - ϵ₁) / (1 + rfₚ^2)
        +
        (ϵ₁ - ϵ₂) / (1 + rfₛ^2)
        + ϵ₂
    )


    η = (2 + ϵ′) / ϵ′′     # equation 3
    Kₗ = 0.819 * f / (ϵ′′ * (1 + η^2))     # equation 2
    return (; Kₗ, η, ϵ′′, ϵ′)
end

# This is implementing Equation 12/14
function _K_L(f)
    nt = _Kₗ(f, 273.75)
    A₁ = 0.1522
    A₂ = 11.51
    A₃ = -10.4912
    f₁ = -23.9589
    f₂ = 219.2096
    σ₁ = 3.2991e3
    σ₂ = 2.7595e6
    K_L = nt.Kₗ * (
        A₁ * exp(-(f - f₁)^2 / σ₁) +
        A₂ * exp(-(f - f₂)^2 / σ₂) +
        A₃
    )
    return (; K_L, nt...)
end

# Log-normal parameters bi-linearly interpolated from the four grid points around `latlon`. `cloudfree` is true when the probability of cloud is at most 0.02 % at any of the four points, in which case the attenuation is zero (Section 3.3, note). The maps hold NaN for mL and sL where the probability of cloud is below 0.02 %, so a NaN value never reaches equation 15. The guard uses `<=` rather than the maps' `<` because the Recommendation defines no approximation at the threshold either (Section 3.3, note: "PL ≤ 0.02"), making it the wider, conservative check
function _lognormalparameters(latlon::LatLon)
    mL_itp, sL_itp, PL_itp = @something(ANNUAL_DATA.lognormal, let
        initialize_lognormal!()
        ANNUAL_DATA.lognormal
    end)::NTuple{3, SGD_TYPE}
    (; idxs, δr, δc) = ItuRP1144.bilinear_itp_inputs(latlon, latrange, lonrange)
    cloudfree = any(i -> PL_itp.data[i] <= 0.02, idxs)
    mL = mL_itp(idxs, δr, δc)
    sL = sL_itp(idxs, δr, δc)
    PL = PL_itp(idxs, δr, δc)
    return (; mL, sL, PL, cloudfree)
end

# Section 3.3, equation 15, with the intermediate values of the validation sheet
function _cloudattenuation_lognormal(latlon::LatLon, f::Real, el::Real, p::Real)
    (; K_L) = _K_L(f)
    (; mL, sL, PL, cloudfree) = _lognormalparameters(latlon)
    lognormal_term = (cloudfree || p >= PL) ? 0.0 : exp(mL + sL * Qinv(p / PL))
    Ac_zenith = K_L * lognormal_term
    Ac = Ac_zenith / sin(deg2rad(el))
    return (; K_L, mL, sL, PL, lognormal_term, Ac_zenith, Ac)
end

#endregion internal functions

"""
    liquidwatercontent(latlon, p)
    liquidwatercontent(lat::Number, lon::Number, args...; kwargs...)

Computes the integrated liquid water content at a given location and exceedance probability based on the digital annual maps in Part 1 of the Recommendation P.840-8.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p`: exceedance probability (%)   
"""
function liquidwatercontent(latlon, p; warn=!SUPPRESS_WARNINGS[])
    latlon = tolatlon(latlon)
    itp = @something(ANNUAL_DATA.ccdf,let
        initialize!()
        ANNUAL_DATA.ccdf
    end)::SquareGridStatisticalData{SGD_TYPE}
    return itp(latlon, p; warn, kind = "the integrated liquid water content")
end

"""
    cloudattenuation(latlon, f, elevation, p)
    cloudattenuation(lat::Number, lon::Number, args...; kwargs...)

Computes annual cloud attenuation along a slant path based on Section 3. 
    
# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `f`: frequency (GHz)
- `el`: elevation angle (degrees)
- `p`: exceedance probability (%)

# Return
- `Acloud::Real`: slant path cloud attenuation (dB)
"""
function cloudattenuation(latlon, f, el, p; warn=!SUPPRESS_WARNINGS[])
    # We don't preprocess the latlon as that is only used in liquidwatercontent which already preprocess
    L = liquidwatercontent(latlon, p)
    return cloudattenuation(latlon, f, el; L, warn)
end
function cloudattenuation(
    latlon,
    f,
    el;
    L,
    warn=!SUPPRESS_WARNINGS[]
)
    el = _todeg(el)
    f = _toghz(f)
    5 ≤ el ≤ 90 || !warn || @noinline(@warn("ItuR840.cloudattenuation only supports elevation angles between 5 and 90 degrees.\nThe given elevation angle $el degrees is outside this range so results may be inaccurate."))
    1 ≤ f ≤ 200 || !warn || @noinline(@warn("ItuR840.cloudattenuation only supports frequencies between 1 and 200 GHz.\nThe given frequency $f GHz is outside this range so results may be inaccurate."))
    
    # Section 3.2, equation 12
    (; K_L) = _K_L(f)

    # equation 13
    Acloud = L * K_L / sin(el |> deg2rad)
    return Acloud
end

"""
    lognormalparameters(latlon)
    lognormalparameters(lat::Number, lon::Number)

Parameters of the log-normal approximation to the annual statistics of integrated cloud liquid water content at the given location, bi-linearly interpolated from the Part 14 digital maps of ITU-R P.840-9 (Section 3.3).

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.

# Return
A `NamedTuple` with fields
- `mL`: log-normal mean parameter
- `sL`: log-normal standard deviation parameter
- `PL`: probability of cloud (%)

`mL` and `sL` are `NaN` where the maps define no approximation (probability of cloud below 0.02 % at a surrounding grid point, mostly near the poles).
"""
function lognormalparameters(latlon)
    (; mL, sL, PL) = _lognormalparameters(tolatlon(latlon))
    return (; mL, sL, PL)
end

"""
    cloudattenuation_lognormal(latlon, f, el, p)
    cloudattenuation_lognormal(lat::Number, lon::Number, args...; kwargs...)

Log-normal approximation to the annual slant path cloud attenuation of Section 3.3 (equation 15), the form used by the time series synthesis of ITU-R P.1853.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `f`: frequency (GHz)
- `el`: elevation angle (degrees)
- `p`: exceedance probability (%), within `(0, 100]`

# Return
- `Ac::Float64`: slant path cloud attenuation (dB). Zero when `p` is at or above the probability of cloud, and wherever the maps define no approximation (probability of cloud at most 0.02 % at any of the four surrounding grid points).
"""
function cloudattenuation_lognormal(latlon, f, el, p; warn=!SUPPRESS_WARNINGS[])
    latlon = tolatlon(latlon)
    el = _todeg(el)
    f = _toghz(f)
    0 < p <= 100 || throw(ArgumentError("p must be an exceedance probability in percent within (0, 100], got $p"))
    5 ≤ el ≤ 90 || !warn || @noinline(@warn("ItuR840.cloudattenuation_lognormal only supports elevation angles between 5 and 90 degrees.\nThe given elevation angle $el degrees is outside this range so results may be inaccurate."))
    1 ≤ f ≤ 200 || !warn || @noinline(@warn("ItuR840.cloudattenuation_lognormal only supports frequencies between 1 and 200 GHz.\nThe given frequency $f GHz is outside this range so results may be inaccurate."))
    return _cloudattenuation_lognormal(latlon, f, el, p).Ac
end

end # module ItuRP840
