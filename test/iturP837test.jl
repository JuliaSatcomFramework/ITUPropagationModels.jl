@testitem "P.837-7 - Characteristics of precipitation for propagation modelling" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P.837-7 Rp")
        map(eachrow(sheet["C69:F76"])) do row
            (;
                ll=LatLon(row[1], row[2]),
                Rp=row[4],
            )
        end
    end
    for entry in entries
        (; ll, Rp) = entry
        @test ItuRP837.rainfallrate001(ll) ≈ Rp rtol = error_tolerance
    end
end

@testitem "P.837-7 - Rain probability and rain rate at any p" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P.837-7 Rp")
        map(eachrow(sheet["C22:AR61"])) do row
            (;
                inputs = (;
                    ll = LatLon(row[1], row[2]),
                    p = row[3],
                ),
                out = (;
                    MT = ntuple(m -> row[3 + m], 12),
                    T_celsius = ntuple(m -> row[15 + m], 12),
                    r = ntuple(m -> row[27 + m], 12),
                    P0 = row[40],
                    Rp = row[41],
                    actualP = row[42],
                ),
            )
        end
    end
    @test length(entries) == 40
    for n in eachindex(entries)
        (; inputs, out) = entries[n]
        (; ll, p) = inputs
        (; MT, T, r, P0m, P0) = ItuRP837._rainprobability(ll)
        @test all(m -> isapprox(MT[m], out.MT[m]; rtol = error_tolerance), 1:12)
        @test all(m -> isapprox(T[m], out.T_celsius[m] + 273.15; rtol = error_tolerance), 1:12)
        @test all(m -> isapprox(r[m], out.r[m]; rtol = error_tolerance), 1:12)
        @test P0 ≈ out.P0 rtol = error_tolerance
        @test ItuRP837.rainprobability(ll) == P0
        Rp = ItuRP837.rainfallrate(ll, p)
        if ismissing(out.actualP)
            # p exceeds the probability of rain: no rain rate is defined
            @test Rp == 0
            @test out.Rp == 0
        else
            # The sheet solves for Rp iteratively and records the probability it actually reached in
            # column AR, so the forward model is checked exactly and the root only loosely.
            @test ItuRP837._exceedanceprobability(out.Rp, r, P0m) ≈ out.actualP rtol = error_tolerance
            @test Rp ≈ out.Rp rtol = 1e-3
            if p == 0.01
                @test Rp == ItuRP837.rainfallrate001(ll)
            else
                @test ItuRP837._exceedanceprobability(Rp, r, P0m) ≈ p rtol = 1e-9
            end
        end
    end

    ll = LatLon(41.9, 12.49)
    @test ItuRP837.rainfallrate(ll, 0.01) == ItuRP837.rainfallrate001(ll)
    @test ItuRP837.rainfallrate(41.9, 12.49, 0.1) == ItuRP837.rainfallrate(ll, 0.1)
    @test ItuRP837.rainprobability(41.9, 12.49) == ItuRP837.rainprobability(ll)
    # `allocations` (from setup_common) calls inside a function; `@allocated` at test-module top level boxes the non-const global arguments and reports spurious bytes
    @test allocations(ItuRP837.rainprobability, ll) == 0
    @test allocations(ItuRP837.rainfallrate, ll, 0.1) == 0
end
