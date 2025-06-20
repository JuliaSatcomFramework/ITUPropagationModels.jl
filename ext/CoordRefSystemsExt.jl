module CoordRefSystemsExt

using ITUPropagationModels: ITUPropagationModels, altitude_from_location, LatLon
using CoordRefSystems: LatLonAlt, LatLon as CLL

# Convert method
Base.convert(::Type{LatLon}, location::Union{LatLonAlt, CLL}) = LatLon(location.lat, location.lon)

# Altitude method for LatLonAlt
ITUPropagationModels.altitude_from_location(location::LatLonAlt) = location.alt

end