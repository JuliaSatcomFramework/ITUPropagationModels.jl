include(joinpath(@__DIR__, "common.jl"))

# Returns the single archive entry whose name matches `pattern`, or errors listing every entry
function find_entry(reader, pattern::Regex)
    names = filter(n -> occursin(pattern, n), zip_names(reader))
    length(names) == 1 || error("Expected exactly one entry matching $pattern, found $names among $(zip_names(reader))")
    return only(names)
end

function create_p837_monthly_artifact()
    artifact_name = "p837_monthly"
    _artifact_hash = Artifacts.artifact_hash(artifact_name, artifact_toml)

    if isnothing(_artifact_hash) || !Artifacts.artifact_exists(_artifact_hash)
        _artifact_hash = Artifacts.create_artifact() do artifact_folder
            # Same archive used by p837_R001.jl; it also contains the monthly total rainfall maps.
            # This is the P.837-7 edition; ITU now serves it under the superseded ("S") suffix
            # since P.837-7 was superseded by P.837-8.
            url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.837-7-201706-S!!ZIP-E.zip"
            zip_path = download_itu(url, joinpath(downloads_dir, "p837_R001.zip"))

            latres = 0.25
            lonres = 0.25
            # The MT grid is padded by half a cell beyond the poles and the antimeridian
            latrange = range(-90.125, 90.125, step=latres)
            lonrange = range(-180.125, 180.125, step=lonres)
            matsize = (length(latrange), length(lonrange))

            open(joinpath(artifact_folder, "README"), "w") do io
                println(io, "This folder contains the monthly mean total rainfall maps (mm) of the ITU-R P.837-7 recommendation, directly in binary format.")
                println(io)
                println(io, "It was automatically generated from the TXT files of the ITU-R P.837-7 recommendation available at the following URL:")
                println(io)
                println(io, url)
                println(io, "The matrices stored into each of the binary files corresponds to a square lat/lon grid where")
                println(io, "- the latitude range is from -90.125° to 90.125° with a step of $(latres)°")
                println(io, "- the longitude range is from -180.125° to 180.125° with a step of $(lonres)°")
                println(io, "- the size of the grid is $(matsize) elements")
                println(io, "The top-left corner has negative latitude and longitude.")
                println(io)
                println(io, "This artifact was automatically generated using the script at the following URL:")
                println(io, permalink("p837_monthly.jl"))
            end

            top = ZipReader(read(zip_path))
            mid = ZipReader(zip_readentry(top, find_entry(top, r"Maps\.zip$"i)))
            mt = ZipReader(zip_readentry(mid, find_entry(mid, r"MT.*\.zip$"i)))

            for name in filter(n -> endswith(lowercase(n), ".docx"), zip_names(mt))
                open(joinpath(artifact_folder, "ITU_" * basename(name)), "w") do io
                    write(io, zip_readentry(mt, name))
                end
            end

            lat = readdlm(zip_readentry(mt, find_entry(mt, r"^LAT.*\.TXT$"i)), ' ')
            lon = readdlm(zip_readentry(mt, find_entry(mt, r"^LON.*\.TXT$"i)), ' ')
            size(lat) == matsize || error("Unexpected LAT size $(size(lat)), expected $matsize")
            (lat[1, 1] ≈ -90.125 && lat[end, 1] ≈ 90.125 && lon[1, 1] ≈ -180.125 && lon[1, end] ≈ 180.125) || error("Unexpected grid orientation: lat corners $(lat[1, 1]), $(lat[end, 1]); lon corners $(lon[1, 1]), $(lon[1, end])")

            for m in 1:12
                name = find_entry(mt, Regex("MT_?Month_?0?$(m)\\.TXT\$", "i"))
                @info "Converting file $name"
                data = readdlm(zip_readentry(mt, name), ' ')
                size(data) == matsize || error("Unexpected size: $(size(data)) instead of $matsize for file $name")
                eltype(data) === Float64 || error("Non-numeric content in $name; check for trailing spaces")
                open(joinpath(artifact_folder, "MT_Month$(lpad(m, 2, '0')).bin"), "w") do io
                    write(io, data)
                end
            end
        end
    end

    asset_name = "p837_monthly.tar.gz"
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

create_p837_monthly_artifact()
