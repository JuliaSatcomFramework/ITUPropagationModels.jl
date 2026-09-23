include(joinpath(@__DIR__, "common.jl"))

function create_p840_annual_artifact()
    artifact_name = "p840_annual"
    _artifact_hash = Artifacts.artifact_hash(artifact_name, artifact_toml)

    if isnothing(_artifact_hash) || !Artifacts.artifact_exists(_artifact_hash)
        _artifact_hash = Artifacts.create_artifact() do artifact_folder
            # Part 1 holds the annual statistics of integrated cloud liquid water content, Part 14 the parameters of their log-normal approximation
            annual_url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.840Part01-0-202308-I!!ZIP-E.zip"
            lognormal_url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.840Part14-0-202308-I!!ZIP-E.zip"
            annual_zip = download_itu(annual_url, joinpath(downloads_dir, "p840_2023_Part1_annual.zip"))
            lognormal_zip = download_itu(lognormal_url, joinpath(downloads_dir, "p840_2023_Part14_lognormal.zip"))

            latres = 0.25
            lonres = 0.25
            latrange = range(-90, 90, step=latres)
            lonrange = range(-180, 180, step=lonres)
            matsize = (length(latrange), length(lonrange))

            open(joinpath(artifact_folder, "README"), "w") do io
                println(io, "This folder contains data for the ITU-R P.840-9 recommendation (annual statistics of integrated cloud liquid water content, and the parameters of their log-normal approximation) directly in binary format.")
                println(io)
                println(io, "It was automatically generated from the TXT files of Part 1 (L_*.bin) and Part 14 (mL.bin, sL.bin, PL.bin) of the ITU-R P.840-9 recommendation available at the following URLs:")
                println(io)
                println(io, annual_url)
                println(io, lognormal_url)
                println(io, "The matrices stored into each of the binary files corresponds to a square lat/lon grid where")
                println(io, "- the latitude range is from -90° to 90° with a step of $(latres)°")
                println(io, "- the longitude range is from -180° to 180° with a step of $(lonres)°")
                println(io, "- the size of the grid is $(matsize) elements")
                println(io, "The top-left corner has negative latitude and longitude.")
                println(io, "mL.bin and sL.bin contain NaN wherever the probability of cloud PL is below 0.02 %, where the recommendation defines no log-normal approximation.")
                println(io)
                println(io, "This artifact was automatically generated using the script at the following URL:")
                println(io, permalink("p840.jl"))
            end

            for zip_path in (annual_zip, lognormal_zip)
                archive = ZipReader(read(zip_path))
                for name in zip_names(archive)
                    endswith(lowercase(name), "txt") || throw(ArgumentError("Unexpected file type: $name"))
                    @info "Converting file $name"
                    data = readdlm(zip_readentry(archive, name), ' ')
                    size(data) == matsize || error("Unexpected size: $(size(data)) instead of $matsize for file $name")
                    eltype(data) === Float64 || error("Non-numeric content in $name; check for trailing spaces")
                    open(joinpath(artifact_folder, replace(name, ".TXT" => ".bin")), "w") do io
                        write(io, data)
                    end
                end
            end

            # The ITU readme describing every part of the digital maps is published separately as Part 15
            readme_url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.840Part15-0-202308-I!!MSW-E.docx"
            download_itu(readme_url, joinpath(artifact_folder, "ITU_README.docx"))
        end
    end

    asset_name = "p840_annual.tar.gz"
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

create_p840_annual_artifact()
