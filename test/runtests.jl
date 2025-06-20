using TestItemRunner

@testsnippet setup_common begin
    using ITUPropagationModels
    using Test
    using XLSX
    validation_file = joinpath(@__DIR__, "CG-3M3J-13-ValEx-Rev8.3.0.xlsx")

    error_tolerance = 1e-7
end
@testitem "Aqua" begin
    using Aqua
    using ITUPropagationModels
    Aqua.test_all(ITUPropagationModels)
end

@run_package_tests verbose=true