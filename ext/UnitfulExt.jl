module UnitfulExt

using ITUPropagationModels: ITUPropagationModels, _todeg, _toghz, _tokm, LatLon
using Unitful

const Len = Quantity{<:Real,u"𝐋"}
const Freq = Quantity{<:Real,u"𝐓^-1"}
const Deg = Quantity{<:Real,NoDims,typeof(u"°")}
const Rad = Quantity{<:Real,NoDims,typeof(u"rad")}
const Angle = Union{Deg,Rad}

ITUPropagationModels.LatLon(lat::Angle, lon::Angle) = LatLon(_todeg(lat), _todeg(lon))
ITUPropagationModels.LatLon(lat::Real, lon::Angle) = LatLon(lat, _todeg(lon))
ITUPropagationModels.LatLon(lat::Angle, lon::Real) = LatLon(_todeg(lat), lon)

@inline ITUPropagationModels._todeg(val::Angle) = uconvert(u"°", val) |> ustrip
@inline ITUPropagationModels._toghz(val::Freq) = uconvert(u"GHz", val) |> ustrip
@inline ITUPropagationModels._tokm(val::Len) = uconvert(u"km", val) |> ustrip

end