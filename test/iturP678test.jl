@testitem "P.678-3 - Climatic ratio" setup = [setup_common] begin
    # Values read directly from CLIMATIC_RATIO.TXT of the ITU archive: grid points are cell centres, so the values at the odd multiples of 0.25° are exact and the ones at cell corners are the mean of the four surrounding points
    @test ItuRP678.climaticratio(LatLon(45.25, 10.25)) ≈ 0.1702 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(-33.75, 151.25)) ≈ 0.2489 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(0.25, -0.25)) ≈ 0.2187 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(89.75, -179.75)) ≈ 0.2605 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(-89.75, 179.75)) ≈ 0.3938 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(45, 10)) ≈ 0.17035 rtol = 1e-12
    # Longitude wraps across the antimeridian; beyond the last ring of cell centres the poles hold that ring's value
    @test ItuRP678.climaticratio(LatLon(0, 180)) ≈ 0.53135 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(0, -180)) == ItuRP678.climaticratio(LatLon(0, 180))
    @test ItuRP678.climaticratio(LatLon(90, -179.75)) ≈ 0.2605 rtol = 1e-12
    @test ItuRP678.climaticratio(LatLon(-90, 179.75)) ≈ 0.3938 rtol = 1e-12
    @test ItuRP678.climaticratio(45.25, 10.25) == ItuRP678.climaticratio(LatLon(45.25, 10.25))
    @test allocations(ItuRP678.climaticratio, LatLon(45.25, 10.25)) == 0
end

@testitem "P.678-3 - Inter-annual variance and risk" setup = [setup_common] begin
    # Variance of estimation from the full sum of equation 2 over all 2N - 1 terms, computed independently
    refs = (1e-4 => 2.312445232024972e-9, 1e-3 => 6.922310744524693e-8, 1e-2 => 3.3186704436335545e-6, 2e-2 => 1.2155004221000477e-5)
    for (p, ref) in refs
        @test ItuRP678._varianceofestimation(p) ≈ ref rtol = 1e-12
    end

    ll = LatLon(45.25, 10.25)
    rc = ItuRP678.climaticratio(ll)
    ps = (1e-4, 1e-3, 1e-2, 2e-2)
    for p in ps
        (; sigma2, sigma2C, sigma2E) = ItuRP678.interannualvariance(ll, p)
        @test sigma2C == (rc * p)^2
        @test sigma2E == ItuRP678._varianceofestimation(p)
        @test sigma2 == sigma2C + sigma2E
    end
    @test issorted(ps; by = p -> ItuRP678.interannualvariance(ll, p).sigma2)

    # Annex 3: the risk is 0.5 when the yearly probability equals the long-term one, and one standard deviation above it gives Q(1)
    @test ItuRP678.riskofexceedance(ll, 0.01, 0.01) == 0.5
    @test ItuRP678.riskofexceedance(ll, 0.01, 0.02) < 0.5 < ItuRP678.riskofexceedance(ll, 0.01, 0.005)
    sigma = sqrt(ItuRP678.interannualvariance(ll, 0.01).sigma2)
    @test ItuRP678.riskofexceedance(ll, 0.01, 0.01 + sigma) ≈ ITUPropagationModels.Q(1) rtol = 1e-12
    @test ItuRP678.riskofexceedance(45.25, 10.25, 0.01, 0.02) == ItuRP678.riskofexceedance(ll, 0.01, 0.02)
    @test ItuRP678.interannualvariance(45.25, 10.25, 0.01) == ItuRP678.interannualvariance(ll, 0.01)

    @test allocations(ItuRP678.interannualvariance, ll, 0.01) == 0
    @test allocations(ItuRP678.riskofexceedance, ll, 0.01, 0.02) == 0

    @test_logs (:warn, r"between 0.01% and 2%") match_mode=:any ItuRP678.interannualvariance(ll, 0.05)
    @test_logs (:warn, r"between 0.01% and 2%") match_mode=:any ItuRP678.riskofexceedance(ll, 0.05, 0.06)
    @test_logs ItuRP678.interannualvariance(ll, 0.05; warn = false)
    @test_throws "within [0, 1]" ItuRP678.interannualvariance(ll, 5)
    @test_throws "within [0, 1]" ItuRP678.riskofexceedance(ll, 0.01, 1.5)
    @test_throws "forgot to provide one argument" ItuRP678.interannualvariance(45.25, 0.01)
    @test_throws "forgot to provide one argument" ItuRP678.riskofexceedance(45.25, 0.01, 0.02)
end
