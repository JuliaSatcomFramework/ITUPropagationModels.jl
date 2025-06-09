using ITUPropagationModels
using Documenter

# Define custom examples for doctests that might be needed
DocMeta.setdocmeta!(ITUPropagationModels, :DocTestSetup, :(using ITUPropagationModels); recursive=true)

makedocs(;
    modules=[ITUPropagationModels],
    authors="Alberto Mengali <disberd@gmail.com>",
    repo=Remotes.GitHub("JuliaSatcomFramework", "ITUPropagationModels.jl"),
    sitename="ITUPropagationModels.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://JuliaSatcomFramework.github.io/ITUPropagationModels.jl/stable",
    ),
    warnonly = true,
    pages=[
        "Home" => "index.md",
        "API Reference" => "api/main.md",
    ],
)

# This controls whether or not deployment is attempted. It is based on the value
# of the `SHOULD_DEPLOY` ENV variable, which defaults to the `CI` ENV variables or
# false if not present.
should_deploy = get(ENV,"SHOULD_DEPLOY", get(ENV, "CI", "") === "true")

if should_deploy
    @info "Deploying"

deploydocs(
    repo = "github.com/JuliaSatcomFramework/ITUPropagationModels.jl.git",
)

end