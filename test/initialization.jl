@testitem "initialize! loads models by name" begin
    using ITUPropagationModels
    using Test
    ITUPropagationModels.initialize!("none")
    ITUPropagationModels.initialize!(["P837", "P453"])
    @test !isnothing(ItuRP837.R001_DATA.itp)
    @test !isnothing(ItuRP453.NWET_ANNUAL.ccdf)
    @test_throws ArgumentError ITUPropagationModels.initialize!(["P999"])
end

@testitem "P840 loads when only the mean is loaded" begin
    using ITUPropagationModels
    using Test
    # The state a second thread saw while the first one was still loading the P840 maps
    ItuRP840.initialize!()
    ItuRP840.ANNUAL_DATA.ccdf = nothing
    @test ItuRP840.liquidwatercontent(45.0, 9.0, 1.0) > 0
end

@testitem "Concurrent first calls load the data once" begin
    using ITUPropagationModels
    using Test
    ItuRP840.ANNUAL_DATA.ccdf = nothing
    ItuRP840.ANNUAL_DATA.mean = nothing
    results = @test_logs (:info, r"^P840") begin
        fetch.([Threads.@spawn ItuRP840.liquidwatercontent(45.0, 9.0, 1.0) for _ in 1:4])
    end
    @test allequal(results)
end
