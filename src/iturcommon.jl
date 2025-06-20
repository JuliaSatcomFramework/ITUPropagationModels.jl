export LatLon
export IturEnum
export EnumHorizontalPolarization, EnumVerticalPolarization, EnumCircularPolarization
export ItuRVersion

const SUPPRESS_WARNINGS = Ref(false)

struct LatLon
    lat::Float64
    lon::Float64
    function LatLon(lat, lon)
        -90 ≤ lat ≤ 90 || throw(ArgumentError("lat=$lat\nlat (latitude) should be between -90 and 90"))
        lon = rem(lon, 360, RoundNearest)
        new(lat, lon)
    end
end

# This functions are used for processing inputs and allow easier extension to support types from other packages
@inline _todeg(val::Real) = val

# We expects length values to be provided in km
@inline _tokm(val::Real) = val

# We expects inputs in GHz
@inline _toghz(val::Real) = val

"""
    tolatlon(location)

This function converts the location input to a `LatLon` object, by default by calling `convert(LatLon, location)`.

Custom location types that want to implement the interface of ITUPropagationModels should override the `ITUPropagationModels.tolatlon` method to return a `LatLon` object, and optionally the `ITUPropagationModels.altitude_from_location` method if they already store information about the location altitude.
"""
@inline tolatlon(x) = convert(LatLon, x)::LatLon # Type assertion on convert is used to help compiler, see https://github.com/JuliaLang/julia/issues/42372 for more details

"""
    altitude_from_location(location)

This function tries to extract the altitude **(in km)** from the location input provided.

It defaults to converting the location to `latlon` with `ITUPropagationModels.tolatlon` and then calling `ItuRP1511.topographicheight` on it.

Custom location types that want to implement the interface of ITUPropagationModels should override the `ITUPropagationModels.tolatlon` method, and optionally the `ITUPropagationModels.altitude_from_location` method if they already store information about the location altitude.
"""
@inline altitude_from_location(location) = ItuRP1511.topographicheight(tolatlon(location))

@inline _validel(el::Real) = (0 ≤ el ≤ 90) || @noinline(throw(ArgumentError("Elevation angles must be provided between 0 and 90 degrees.\nThe given elevation angle ($el degrees) is not a valid input.")))

Base.show(io::IO, p::LatLon) = print(io, "(", p.lat, ", ", p.lon, ")")

@enum IturEnum begin
    # for ITU-R P.453-14
    EnumWater
    EnumIce

    # for ITU-R P.1511-11 (custom by Kchao)
    EnumHeightAndIndex
    EnumIndexOnly

    # for ITU-R P.838-3
    EnumHorizontalPolarization
    EnumVerticalPolarization
    EnumCircularPolarization
end
function tilt_from_polarization(polarization::IturEnum)
    τ = if polarization == EnumCircularPolarization
        45
    elseif polarization == EnumHorizontalPolarization
        0
    elseif polarization == EnumVerticalPolarization
        90
    else
        throw(ArgumentError("Invalid polarization value in ItuRP838.rainspecificattenuation."))
    end
    return τ
end

struct ItuRVersion
    doctype::String
    recommendation::String
    dashednumber::Int8
    datestring::String
end