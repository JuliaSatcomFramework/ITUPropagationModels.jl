module ItuRP1510

#=
Annual and monthly mean surface temperature at 2 m above ground, derived by the ITU from 36 years of ECMWF ERA Interim data.
Recommendation ITU-R P.837 uses the monthly values to estimate the probability of rain.
=#

using ..ITUPropagationModels: ITUPropagationModels, LatLon, ItuRVersion, tolatlon
using ..ItuRP1144: SquareGridData
using Artifacts

const version = ItuRVersion("ITU-R", "P.1510", 1, "(06/2017)")

# Exports and constructor with separate latitude and longitude arguments
for name in (:surfacemeantemperature,)
    @eval $name(lat::Number, lon::Number, args...; kwargs...) = $name(LatLon(lat, lon), args...; kwargs...)
    @eval export $name
end

#region initialization

const δlat = 0.75
const δlon = 0.75
const latrange = range(-90, 90, step=δlat)
const lonrange = range(-180, 180, step=δlon)
const datasize = (length(latrange), length(lonrange))

const SGD_TYPE = SquareGridData{Float64, typeof(latrange), String}

@kwdef mutable struct TemperatureData
    annual::Union{SGD_TYPE, Nothing} = nothing
    monthly::Union{NTuple{12, SGD_TYPE}, Nothing} = nothing
end

const DATA = TemperatureData()

function initialize!()
    dir = artifact"p1510"
    load(name, id) = SquareGridData(latrange, lonrange, read!(joinpath(dir, name), zeros(datasize)), id)
    DATA.annual = load("T_Annual.bin", "Annual mean surface temperature (K)")
    DATA.monthly = ntuple(Val(12)) do m
        load("T_Month$(lpad(m, 2, '0')).bin", "Monthly mean surface temperature (K), month $m")
    end
    return nothing
end

#endregion initialization

"""
    surfacemeantemperature(latlon)
    surfacemeantemperature(latlon, month::Integer)
    surfacemeantemperature(lat::Number, lon::Number, args...)

Annual (first form) or monthly (second form, `month` in `1:12`) mean surface temperature in kelvin at 2 m above ground, obtained by bi-linear interpolation of the digital maps of ITU-R P.1510-1.

# Arguments
- `latlon`: object representing latitude and longitude, must be convertible to `ITUPropagationModels.LatLon`
  - This function can also be called with separate latitude and longitude as first two arguments `lat` and `lon` as per last method in the signatures above.
- `month`: calendar month, 1 = January.

# Return
- `T::Float64`: mean surface temperature (K)
"""
function surfacemeantemperature(latlon)
    latlon = tolatlon(latlon)
    itp = @something(DATA.annual, let
        initialize!()
        DATA.annual
    end)::SGD_TYPE
    return itp(latlon)
end

function surfacemeantemperature(latlon, month::Integer)
    1 <= month <= 12 || throw(ArgumentError("month must be between 1 and 12, got $month"))
    latlon = tolatlon(latlon)
    monthly = @something(DATA.monthly, let
        initialize!()
        DATA.monthly
    end)::NTuple{12, SGD_TYPE}
    return monthly[month](latlon)
end

end # module ItuRP1510
