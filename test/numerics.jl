@testitem "Numerics - Q and Qinv" begin
    using ITUPropagationModels: Q, Qinv
    @test Q(0) ≈ 0.5
    @test Q(1.96) ≈ 0.024997895148220435 rtol = 1e-12
    @test Q(-1.96) ≈ 1 - 0.024997895148220435 rtol = 1e-12
    for p in (1e-6, 1e-3, 0.01, 0.1, 0.5, 0.9, 0.999)
        @test Q(Qinv(p)) ≈ p rtol = 1e-12
    end
    @test Qinv(0.5) ≈ 0 atol = 1e-15
    @test @allocated(Q(1.0)) == 0
    @test @allocated(Qinv(0.1)) == 0
end

@testitem "Numerics - bisect" begin
    using ITUPropagationModels: bisect
    @test bisect(x -> x^2 - 2, 0, 2) ≈ sqrt(2) atol = 1e-11
    @test bisect(x -> x - 1, 1, 3) == 1.0
    @test bisect(x -> exp(x) - 5, -10, 10; xtol = 1e-9) ≈ log(5) atol = 1e-8
    @test_throws "sign change" bisect(x -> x^2 + 1, -1, 1)
end

@testitem "Numerics - bivariate normal ccdf" begin
    using ITUPropagationModels: bivariate_normal_ccdf, Q
    # Reference values from scipy.stats.multivariate_normal.cdf([-a, -b], cov=[[1, r], [r, 1]])
    refs = [
        (0.0, 0.0, 0.5) => 0.333333333333333,
        (1.0, -0.5, 0.3) => 0.133256135449951,
        (1.6, 1.6, 0.926) => 0.0379427871100931,
        (-1.0, 2.0, -0.8) => 0.00189054801592368,
        (0.5, 0.5, 0.99) => 0.288661945810546,
        (2.0, 1.0, -0.2) => 0.00151519808206194,
        # alpha and rho of the first row of the ITU ValEx sheet "P.618-14 PofA"; expected value is its CB column
        (1.61076848674895, 1.61076848674895, 0.926230316999199) => 3.7076342423710301e-2,
    ]
    for ((a, b, r), ref) in refs
        @test bivariate_normal_ccdf(a, b, r) ≈ ref rtol = 1e-12
    end
    @test bivariate_normal_ccdf(1.0, 2.0, 0.0) == Q(1.0) * Q(2.0)
    @test bivariate_normal_ccdf(1.0, 2.0, 1.0) ≈ Q(2.0) rtol = 1e-14
    @test bivariate_normal_ccdf(-1.0, 0.5, -1.0) ≈ Q(0.5) - Q(1.0) rtol = 1e-14
    @test bivariate_normal_ccdf(Inf, 0.0, 0.5) == 0
    @test bivariate_normal_ccdf(-Inf, -Inf, 0.5) == 1
    @test_throws ArgumentError bivariate_normal_ccdf(0.0, 0.0, 1.5)
    @test @allocated(bivariate_normal_ccdf(1.6, 1.6, 0.926)) == 0
end
