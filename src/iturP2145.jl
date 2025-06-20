module ItuRP2145

#=
This Recommendation provides methods to predict the surface total (barometric) pressure, surface
temperature, surface water vapour density and integrated water vapour content required for the calculation of
gaseous attenuation and related effects on terrestrial and Earth-space paths.
=#

using ..ITUPropagationModels: ITUPropagationModels, LatLon, ItuRVersion, ItuRP1511, ItuRP1144, tolatlon, _tokm, SUPPRESS_WARNINGS, altitude_from_location
using Artifacts: Artifacts, @artifact_str

# Exports and constructor with separate latitude and longitude arguments
for name in (:surfacetemperatureannual, :surfacewatervapourdensityannual, :surfacepressureannual, :surfacewatervapourcontentannual, :annual_surface_values)
    @eval $name(lat::Number, lon::Number, args...; kwargs...) = $name(LatLon(lat, lon), args...; kwargs...)
    @eval export $name
end

const version = ItuRVersion("ITU-R", "P.2145", 0, "(08/2022)")

#region initialization

const δlat = 0.25
const δlon = 0.25
const latrange = range(-90, 90, step=δlat)
const lonrange = range(-180, 180, step=δlon)
const datasize = (length(latrange), length(lonrange))

# exceedance probability, section 1 of ITU-R P.836-6
const psannual = [0.01, 0.02, 0.03, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 3, 5, 10, 20, 30, 50, 60, 70, 80, 90, 95, 99]

# exceedance probability values for reading files
const filespsannual = ["001", "002", "003", "005", "01", "02", "03", "05", "1", "2", "3", "5", "10", "20", "30", "50", "60", "70", "80", "90", "95", "99"]

# This is used as callable struct to define the altitude-dependent scaling function for the various maps part of Recommendation ITU-R P.2145
struct ScaleFunction{S} end
(::ScaleFunction{:T})(Xᵢ′, scaleᵢ, altᵢ; alt) = Xᵢ′ + scaleᵢ * (alt - altᵢ) # This is the scaling function for temperature
(::ScaleFunction)(Xᵢ′, scaleᵢ, altᵢ; alt) = Xᵢ′ * exp(-(alt - altᵢ) / scaleᵢ) # This is the scaling function for P, V and RHO

struct SingleVariableData{S}
    ccdf::Vector{Matrix{Float64}}
    mean::Matrix{Float64}
    scale::Matrix{Float64}
    Z_ground::Matrix{Float64}
    scale_func::ScaleFunction{S}
end
function SingleVariableData{S}() where S
    Z_ground = fill(NaN, datasize)
    ccdf = [fill(NaN, datasize) for _ in filespsannual]
    mean = fill(NaN, datasize)
    scale = fill(NaN, datasize)
    scale_func = ScaleFunction{S}()
    # We create empty data and initialize it with the data in the artifact
    SingleVariableData{S}(ccdf, mean, scale, Z_ground, scale_func) |> initialize!
end

"""
    struct AnnualData

Structure storing the raw Annual Data for the various variables of ITU-R P.2145

The instance used by the P2145 module is stored in the `ANNUAL_DATA` constant.
"""
@kwdef mutable struct AnnualData
    T::Union{SingleVariableData{:T}, Nothing} = nothing
    RHO::Union{SingleVariableData{:RHO}, Nothing} = nothing
    P::Union{SingleVariableData{:P}, Nothing} = nothing
    V::Union{SingleVariableData{:V}, Nothing} = nothing
end

const ANNUAL_DATA = AnnualData()

# This will return the variable in the ANNUAL_DATA struct, initializing it if it is not already initialized
getvariable(::Val{S}) where S = @something getproperty(ANNUAL_DATA, S) setproperty!(ANNUAL_DATA, S, SingleVariableData{S}())

function initialize!(nt::SingleVariableData{kind}) where kind
    # We make sure that Z_ground is also initialized
    @info "P2145: Loading data for $kind variable"
    scalename = if kind === :T
        "TSCH.bin"
    elseif kind === :P
        "PSCH.bin"
    else 
        "VSCH.bin"
    end
    initialize!(nt.scale, kind, scalename)
    # We initialize the Z_ground
    initialize!(nt.Z_ground, kind, "Z_ground.bin")
    # We initialize the mean
    initialize!(nt.mean, kind, "$(kind)_mean.bin")
    # We initialize the ccdf values
    for (i, suffix) in enumerate(filespsannual)
        initialize!(nt.ccdf[i], kind, "$(kind)_$(suffix).bin")
    end
    nt
end

function initialize!(data::Matrix, kind::Symbol, filename::String)
    dir = if kind in (:T, :Z_ground)
        joinpath(artifact"p2145_annual", "T_Annual")
    elseif kind === :RHO
        joinpath(artifact"p2145_annual", "RHO_Annual")
    elseif kind === :V
        joinpath(artifact"p2145_annual", "V_Annual")
    elseif kind === :P
        joinpath(artifact"p2145_annual", "P_Annual")
    end
    read!(joinpath(dir, filename), data)
    return nothing
end

function warnmsg_kind(::SingleVariableData{kind}) where kind
    if kind === :T
        "the annual surface temperature"
    elseif kind === :RHO
        "the annual surface water vapour density"
    elseif kind === :P
        "the annual surface total barometric pressure"
    elseif kind === :V
        "the annual surface integrated water vapour content"
    end
end

# This is a helper function to return indices for faster interpolation using square bilinear interpolation
@inline itp_inputs(latlon::LatLon) = ItuRP1144.bilinear_itp_inputs(latlon, latrange, lonrange)

# This is a helper function to return indices on the pre-computed probability values to use for interpolation
@inline itp_inputs(p::Real; warn, kind) = ItuRP1144.ccdf_itp_inputs(p, psannual; warn, kind)

function (nt::SingleVariableData)(latlon; alt = nothing)
    alt = @something(alt, altitude_from_location(latlon)) |> _tokm
    latlon = tolatlon(latlon)
    (; idxs, δr, δc) = itp_inputs(latlon)
    bilinear_interpolation(nt.mean, nt.scale, nt.Z_ground, nt.scale_func, idxs, δr, δc; alt)
end
function (nt::SingleVariableData)(latlon, p::Real; alt = nothing, warn = !SUPPRESS_WARNINGS[])
    alt = @something(alt, altitude_from_location(latlon)) |> _tokm
    latlon = tolatlon(latlon)
    (; idxs, δr, δc) = itp_inputs(latlon)
    (; pindexabove, pindexbelow) = itp_inputs(p; warn, kind = warnmsg_kind(nt))
    
    Tabove = bilinear_interpolation(nt.ccdf[pindexabove], nt.scale, nt.Z_ground, nt.scale_func, idxs, δr, δc; alt)
    pindexabove == pindexbelow && return Tabove
    Tbelow = bilinear_interpolation(nt.ccdf[pindexbelow], nt.scale, nt.Z_ground, nt.scale_func, idxs, δr, δc; alt)
    psabove = psannual[pindexabove]
    psbelow = psannual[pindexbelow]
    T = (Tabove - Tbelow) / log(psabove/psbelow) * log(p/psbelow) + Tbelow
    return T
end

# This will compute first altitude-based scaling using function `f` (Following ITU-R P.2145 guidelines) to each of the 4 neighboring points and then perform bilinear interpolation as per ITU-R P.1144-12
function bilinear_interpolation(data::Matrix, scale::Matrix, Z::Matrix, f::F, idxs::NTuple{4, CartesianIndex}, δr::Real, δc::Real; alt = 0.0) where F
    vals = ntuple(4) do i
        idx = idxs[i]
        Xᵢ′ = data[idx]
        altᵢ = Z[idx]
        scaleᵢ = scale[idx]
        f(Xᵢ′, scaleᵢ, altᵢ; alt)
    end
    return ItuRP1144.bilinear_interpolation(vals, δr, δc)
end

#endregion initialization

"""
    T̄ₛ = surfacetemperatureannual(latlon; alt = nothing)
    Tₛ(p) = surfacetemperatureannual(latlon, p::Real; alt = nothing)
    surfacetemperatureannual(lat::Number, lon::Number, args...; kwargs...)

Computes annual surface temperature based Section 2 of the P2145-0
Recommendation and assuming the surface to be located at `alt` km above sea
level.

If the function is called with the `LatLon` target position as sole positional
argument, the function will return the **mean** surface temperature at the
target location following the procedure described in Section 2.2 of the P2145-0
Recommendation.
If the optional second argument `p` is provided, this is interpreted as the
target exceedance probability and the function will follow the procedure
described in Section 2.1 of the P2145-0 Recommendation.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p::Real`: exceedance probability (%)

# Keyword Arguments
- `alt::Union{Nothing, Real}`: altitude (km). If provided as `nothing` (default) this will be computed based on the location and following Recommendation P1511-3

# Returns
- `T̄ₛ::Float64` or `Tₛ(p)::Float64`: computed annual surface temperature (°K)
"""
surfacetemperatureannual(args...; kwargs...) = getvariable(Val(:T))(args...; kwargs...)

"""
    ρ̄ₛ = surfacewatervapourdensityannual(latlon; alt = nothing)
    ρₛ(p) = surfacewatervapourdensityannual(latlon, p::Real; alt = nothing)
    surfacewatervapourdensityannual(lat::Number, lon::Number, args...; kwargs...)

Computes annual surface water vapour density based Section 2 of the P2145-0
Recommendation and assuming the surface to be located at `alt` km above sea
level.

If the function is called with the `LatLon` target position as sole positional
argument, the function will return the **mean** surface water vapour density at the
target location following the procedure described in Section 2.2 of the P2145-0
Recommendation.
If the optional second argument `p` is provided, this is interpreted as the
target exceedance probability and the function will follow the procedure
described in Section 2.1 of the P2145-0 Recommendation.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p::Real`: exceedance probability (%)

# Keyword Arguments
- `alt::Union{Nothing, Real}`: altitude (km). If provided as `nothing` (default) this will be computed based on the location and following Recommendation P1511-3

# Returns
- `ρ̄ₛ::Float64` or `ρₛ(p)::Float64`: computed annual surface water vapour density (g/m^3)
"""
surfacewatervapourdensityannual(args...; kwargs...) = getvariable(Val(:RHO))(args...; kwargs...)

"""
    P̄ₛ = surfacepressureannual(latlon; alt = nothing)
    Pₛ(p) = surfacepressureannual(latlon, p::Real; alt = nothing)
    surfacepressureannual(lat::Number, lon::Number, args...; kwargs...)

Computes annual surface total barometric pressure based Section 2 of the P2145-0
Recommendation and assuming the surface to be located at `alt` km above sea
level.  

If the function is called with the `LatLon` target position as sole positional
argument, the function will return the **mean** total barometric pressure at the
target location following the procedure described in Section 2.2 of the P2145-0
Recommendation.
If the optional second argument `p` is provided, this is interpreted as the
target exceedance probability and the function will follow the procedure
described in Section 2.1 of the P2145-0 Recommendation. 

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p::Real`: exceedance probability (%)

# Keyword Arguments
- `alt::Union{Nothing, Real}`: altitude (km). If provided as `nothing` (default) this will be computed based on the location and following Recommendation P1511-3    

# Returns
- `P̄ₛ::Float64` or `Pₛ(p)::Float64`: computed annual total barometric pressure (hPa)
"""
surfacepressureannual(args...; kwargs...) = getvariable(Val(:P))(args...; kwargs...)


"""
    V̄ₛ = surfacewatervapourcontentannual(latlon; alt = nothing)
    Vₛ(p) = surfacewatervapourcontentannual(latlon, p::Real; alt = nothing)
    surfacewatervapourcontentannual(lat::Number, lon::Number, args...; kwargs...)

Computes annual surface integrated water vapour content based Section 2 of the P2145-0
Recommendation and assuming the surface to be located at `alt` km above sea
level.

If the function is called with the `LatLon` target position as sole positional
argument, the function will return the **mean** integrated water vapour content at the
target location following the procedure described in Section 2.2 of the P2145-0
Recommendation.
If the optional second argument `p` is provided, this is interpreted as the 
target exceedance probability and the function will follow the procedure
described in Section 2.1 of the P2145-0 Recommendation.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `p::Real`: exceedance probability (%)      

# Keyword Arguments
- `alt::Union{Nothing, Real}`: altitude (km). If provided as `nothing` (default) this will be computed based on the location and following Recommendation P1511-3

# Returns
- `V̄ₛ::Float64` or `Vₛ(p)::Float64`: computed annual integrated water vapour content (g/m^2)
"""
surfacewatervapourcontentannual(args...; kwargs...) = getvariable(Val(:V))(args...; kwargs...)


"""
    annual_surface_values(latlon[, p]; alt = nothing)

This function is used to provide the annual surface values for variables refrenced in P676 and P618:
- `P`: The total barometric pressure
- `T`: The surface temperature
- `ρ`: The surface water vapour density

The function can be called with the outage probability `p` as second positional argument to compute the statsitical values, or without to compute the mean values.

It also compute the altitude of the provided location if provided as nothing as kwarg
"""
function annual_surface_values(latlon, args...; alt = nothing)
    alt = @something(alt, altitude_from_location(latlon)) |> _tokm
    latlon = tolatlon(latlon)
    P = surfacepressureannual(latlon, args...; alt)
    T = surfacetemperatureannual(latlon, args...; alt)
    ρ = surfacewatervapourdensityannual(latlon, args...; alt)
    return (; P, T, ρ, alt)
end

end # module ItuRP2145
