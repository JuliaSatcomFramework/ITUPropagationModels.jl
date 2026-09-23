include(joinpath(@__DIR__, "common.jl"))

function create_p678_artifact()
    artifact_name = "p678"
    _artifact_hash = Artifacts.artifact_hash(artifact_name, artifact_toml)

    if isnothing(_artifact_hash) || !Artifacts.artifact_exists(_artifact_hash)
        _artifact_hash = Artifacts.create_artifact() do artifact_folder
            # Direct download of the climatic ratio map attached to ITU-R P.678-3
            url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.678-3-201507-I!!ZIP-E.zip"
            zip_path = download_itu(url, joinpath(downloads_dir, "p678.zip"))

            res = 0.5
            # The grid is cell-centred: it runs from -89.75° to 89.75° in latitude and from -179.75° to 179.75° in longitude
            latrange = range(-89.75, 89.75, step=res)
            lonrange = range(-179.75, 179.75, step=res)
            matsize = (length(latrange), length(lonrange))

            open(joinpath(artifact_folder, "README"), "w") do io
                println(io, "This folder contains the climatic ratio map of the ITU-R P.678-3 recommendation, directly in binary format.")
                println(io)
                println(io, "It was automatically generated from the TXT files of the ITU-R P.678-3 recommendation available at the following URL:")
                println(io)
                println(io, url)
                println(io, "The matrix stored in the binary file corresponds to a square lat/lon grid of cell centres where")
                println(io, "- the latitude range is from -89.75° to 89.75° with a step of $(res)°")
                println(io, "- the longitude range is from -179.75° to 179.75° with a step of $(res)°")
                println(io, "- the size of the grid is $(matsize) elements")
                println(io, "The top-left corner has negative latitude and longitude (the ITU TXT file runs north to south and is flipped here).")
                println(io)
                println(io, "This artifact was automatically generated using the script at the following URL:")
                println(io, permalink("p678.jl"))
            end

            archive = ZipReader(read(zip_path))
            open(joinpath(artifact_folder, "ITU_Readme678.txt"), "w") do io
                write(io, zip_readentry(archive, "Readme678.txt"))
            end

            # The LAT/LON companion files pin down the grid orientation assumed above
            lat = readdlm(zip_readentry(archive, "LAT.TXT"), ' ')
            lon = readdlm(zip_readentry(archive, "LON.TXT"), ' ')
            size(lat) == matsize || error("Unexpected LAT size $(size(lat)), expected $matsize")
            (lat[1, 1] ≈ 89.75 && lat[end, 1] ≈ -89.75 && lon[1, 1] ≈ -179.75 && lon[1, end] ≈ 179.75) || error("Unexpected grid orientation: lat corners $(lat[1, 1]), $(lat[end, 1]); lon corners $(lon[1, 1]), $(lon[1, end])")

            name = "CLIMATIC_RATIO.TXT"
            @info "Converting file $name"
            data = readdlm(zip_readentry(archive, name), ' ')
            size(data) == matsize || error("Unexpected size: $(size(data)) instead of $matsize for file $name")
            eltype(data) === Float64 || error("Non-numeric content in $name; check for trailing spaces")
            open(joinpath(artifact_folder, "CLIMATIC_RATIO.bin"), "w") do io
                write(io, reverse(data; dims=1))
            end
        end
    end

    asset_name = "p678.tar.gz"
    tarball_path = joinpath(assets_dir, asset_name)
    tarball_sha = if !isfile(tarball_path)
        @info "Creating the artifact tarball"
        Artifacts.archive_artifact(_artifact_hash, tarball_path)
    else
        sha256sum(tarball_path)
    end
    release_url = release_root_url * asset_name
    @info "Updating the Artifacts.toml file"
    Artifacts.bind_artifact!(artifact_toml, artifact_name, _artifact_hash; force=true, download_info=[(release_url, tarball_sha)])
end

create_p678_artifact()
