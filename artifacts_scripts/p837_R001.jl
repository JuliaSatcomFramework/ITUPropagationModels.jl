include(joinpath(@__DIR__, "common.jl"))

function create_p837_R001_artifact()
    artifact_name = "p837_R001"
    _artifact_hash = Artifacts.artifact_hash(artifact_name, artifact_toml)

    if isnothing(_artifact_hash) || !Artifacts.artifact_exists(_artifact_hash)
        _artifact_hash = Artifacts.create_artifact() do artifact_folder
            # This is the URL for direct download of the zip file containing the components of the ITU-R P.837-7 recommendation
            url = "https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.837-7-201706-I!!ZIP-E.zip"

            zip_path = joinpath(downloads_dir, "p837_R001.zip")
            if !isfile(zip_path)
                @info "Downloading raw zip file for ITU-R P.837-7 from ITU Database"
                Downloads.download(url, zip_path)
                @info "Download completed"
            end

            latres = 0.125
            lonres = 0.125

            latrange = range(-90, 90, step=latres)
            lonrange = range(-180, 180, step=lonres)

            matsize = (length(latrange), length(lonrange))

            # Add a README
            open(joinpath(artifact_folder, "README"), "w") do io
                println(io, "This folder contains Maps for the rainfall rate exceeded 0.01% of the time for the ITU-R P.837-7 recommendation, directly in binary format.")
                println(io)
                println(io, "It was automatically generated from the TXT files of the ITU-R P.837-7 recommendation available at the following URL:")
                println(io)
                println(io, url)
                println(io, "The matrices stored into each of the binary files corresponds to a square lat/lon grid where")
                println(io, "- the latitude range is from -90° to 90° with a step of $(latres)°")
                println(io, "- the longitude range is from -180° to 180° with a step of $(lonres)°")
                println(io, "- the size of the grid is $(matsize) elements")
                println(io, "The top-left corner has negative latitude and longitude.")
                println(io)
                println(io, "This artifact was automatically generated using the script at the following URL:")
                println(io, permalink("p837_R001.jl"))
            end

            top = ZipReader(read(zip_path))
            archive = let 
                mid = ZipReader(zip_readentry(top, "R-REC-P.837-7-Maps.zip"))
                bottom = ZipReader(zip_readentry(mid, "P.837_R001_Maps.zip"))
            end
            # We copy the original docx readme for reference
            itu_readme = "Readme_P.837_R001.docx"
            open(joinpath(artifact_folder, "ITU_" * itu_readme), "w") do io
                write(io, zip_readentry(archive, itu_readme))
            end


            name = "R001.TXT"
            @info "Converting file $name"
            filecontent = zip_readentry(archive, name)
            binfile = joinpath(artifact_folder, replace(name, ".TXT" => ".bin"))
            data = readdlm(filecontent, ' ')
            size(data) == matsize || error("Unexpected size: $(size(data)) instead of $matsize for file $name")
            open(binfile, "w") do io
                write(io, data)
            end
        end
    end


    asset_name = "p837_R001.tar.gz"
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

create_p837_R001_artifact()
