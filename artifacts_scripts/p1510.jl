include(joinpath(@__DIR__, "common.jl"))

function create_p1510_artifact()
    artifact_name = "p1510"
    _artifact_hash = Artifacts.artifact_hash(artifact_name, artifact_toml)

    if isnothing(_artifact_hash) || !Artifacts.artifact_exists(_artifact_hash)
        _artifact_hash = Artifacts.create_artifact() do artifact_folder
            # Direct download of the digital maps attached to ITU-R P.1510-1
            url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.1510-1-201706-I!!ZIP-E.zip"
            zip_path = download_itu(url, joinpath(downloads_dir, "p1510.zip"))

            latres = 0.75
            lonres = 0.75
            latrange = range(-90, 90, step=latres)
            lonrange = range(-180, 180, step=lonres)
            matsize = (length(latrange), length(lonrange))

            open(joinpath(artifact_folder, "README"), "w") do io
                println(io, "This folder contains the annual and monthly mean surface temperature maps (K, 2 m above ground) of the ITU-R P.1510-1 recommendation, directly in binary format.")
                println(io)
                println(io, "It was automatically generated from the TXT files of the ITU-R P.1510-1 recommendation available at the following URL:")
                println(io)
                println(io, url)
                println(io, "The matrices stored into each of the binary files corresponds to a square lat/lon grid where")
                println(io, "- the latitude range is from -90° to 90° with a step of $(latres)°")
                println(io, "- the longitude range is from -180° to 180° with a step of $(lonres)°")
                println(io, "- the size of the grid is $(matsize) elements")
                println(io, "The top-left corner has negative latitude and longitude.")
                println(io)
                println(io, "This artifact was automatically generated using the script at the following URL:")
                println(io, permalink("p1510.jl"))
            end

            archive = ZipReader(read(zip_path))
            itu_readme = "Readme_P.1510.docx"
            open(joinpath(artifact_folder, "ITU_" * itu_readme), "w") do io
                write(io, zip_readentry(archive, itu_readme))
            end

            # The LAT/LON companion files pin down the grid orientation assumed above
            lat = readdlm(zip_readentry(archive, "LAT_T.TXT"), ' ')
            lon = readdlm(zip_readentry(archive, "LON_T.TXT"), ' ')
            size(lat) == matsize || error("Unexpected LAT_T size $(size(lat)), expected $matsize")
            (lat[1, 1] ≈ -90 && lat[end, 1] ≈ 90 && lon[1, 1] ≈ -180 && lon[1, end] ≈ 180) || error("Unexpected grid orientation in LAT_T/LON_T")

            names = ("T_Annual.TXT", ntuple(m -> "T_Month$(lpad(m, 2, '0')).TXT", 12)...)
            for name in names
                @info "Converting file $name"
                data = readdlm(zip_readentry(archive, name), ' ')
                size(data) == matsize || error("Unexpected size: $(size(data)) instead of $matsize for file $name")
                eltype(data) === Float64 || error("Non-numeric content in $name; check for trailing spaces")
                open(joinpath(artifact_folder, replace(name, ".TXT" => ".bin")), "w") do io
                    write(io, data)
                end
            end
        end
    end

    asset_name = "p1510.tar.gz"
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

create_p1510_artifact()
