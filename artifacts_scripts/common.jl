using Pkg: Artifacts
using Downloads
using SHA
using ZipArchives
using DelimitedFiles
using LibGit2

function sha256sum(tarball_path)
    return open(tarball_path, "r") do io
        return bytes2hex(sha256(io))
    end
end
downloads_dir = joinpath(@__DIR__, "..", "downloads")
isdir(downloads_dir) || mkdir(downloads_dir)

assets_dir = joinpath(@__DIR__, "..", "assets")
isdir(assets_dir) || mkdir(assets_dir)

artifact_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

release_root_url = "https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl/releases/download/artifacts_releases/"

function permalink(filename::AbstractString) 
    sha = LibGit2.head(dirname(@__DIR__))
    root = "https://github.com/JuliaSatcomFramework/ITUPropagationModels.jl/blob"
    return join([root, sha, "artifacts_scripts", filename], "/")
end

function parseline(str::AbstractString, ::Type{T} = Float64) where T
    cleaned = replace(strip(str), r" +" => ' ')
    return map(x -> parse(T, x), split(cleaned, ' '))
end

function parsematrix(file::AbstractString, ::Type{T} = Float64) where T
    return stack(s -> parseline(s, T), eachline(file)) |> permutedims
end

# The ITU download server rejects requests without browser-like headers and then answers with an HTML page instead of the archive.
function download_itu(url::AbstractString, path::AbstractString)
    if !isfile(path)
        @info "Downloading $url"
        headers = [
            "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            "Referer" => "https://www.itu.int/rec/R-REC-P/en",
            "Accept" => "*/*",
        ]
        Downloads.download(url, path; headers)
    end
    magic = open(io -> read(io, 2), path)
    if magic != UInt8['P', 'K']
        rm(path)
        error("ITU returned a non-zip response for $url. Download it in a browser and save it as $path, then rerun.")
    end
    return path
end

