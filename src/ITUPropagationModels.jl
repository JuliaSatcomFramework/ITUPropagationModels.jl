module ITUPropagationModels

using Artifacts
using Preferences: load_preference

export attenuations

#region package export

export ItuRP840

export ItuRP453
export ItuRP1144
export ItuRP1511
export ItuRP2145
export ItuRP835
export ItuRP838
export ItuRP839
export ItuRP837
export ItuRP676

export ItuRP618

#endregion package export

#region include

include("iturcommon.jl")

include("iturP1144.jl") # Interpolations

include("iturP840.jl")

include("iturP453.jl")
include("iturP1511.jl")
include("iturP2145.jl")
include("iturP835.jl")
include("iturP838.jl")
include("iturP839.jl")
include("iturP837.jl")
include("iturP676.jl")

include("iturP618.jl")

include("helpers.jl")
export attenuations_intermediate_terms

using .ItuRP618: attenuations

#endregion include

#region initialization

# The models that load digital maps from artifacts on first use.
const LAZY_MODELS = (; P840 = ItuRP840, P837 = ItuRP837, P453 = ItuRP453, P2145 = ItuRP2145)

"""
    ITUPropagationModels.initialize!(models = "all")

Loads the digital maps of `models` into memory. Each model loads its maps on first use anyway, so
call this to pay the load time up front, for example before starting threads.

`models` is `"all"`, `"none"`, or a vector of model names among `"P840"`, `"P837"`, `"P453"`,
and `"P2145"`. A model already loaded is not loaded again.

When the package loads, it calls this function with the `preload` preference, which is
`"none"` when not set. Set it with Preferences.jl, then restart Julia:

```julia
using Preferences, ITUPropagationModels
set_preferences!(ITUPropagationModels, "preload" => ["P840", "P2145"])
```
"""
function initialize!(models = "all")
    names = models == "all" ? keys(LAZY_MODELS) : models == "none" ? () : Symbol.(models)
    for name in names
        haskey(LAZY_MODELS, name) || throw(ArgumentError("Unknown model \"$name\": use \"all\", \"none\", or names among $(join(string.(keys(LAZY_MODELS)), ", "))"))
        LAZY_MODELS[name].initialize!()
    end
    return nothing
end

function __init__()
    # Loading a downstream package during its precompilation runs this too: skip the maps there.
    ccall(:jl_generating_output, Cint, ()) == 1 && return nothing
    initialize!(load_preference(@__MODULE__, "preload", "none"))
end

#endregion initialization


end # module ITUPropagationModels
