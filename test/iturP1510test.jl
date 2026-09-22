@testitem "P.1510-1 - Monthly mean surface temperature" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P.837-7 Rp")
        map(eachrow(sheet["C22:AC61"])[1:5:end]) do row
            (;
                ll = LatLon(row[1], row[2]),
                T_celsius = ntuple(m -> row[15 + m], 12),
            )
        end
    end
    @test length(entries) == 8
    for entry in entries
        (; ll, T_celsius) = entry
        for m in 1:12
            @test ItuRP1510.surfacemeantemperature(ll, m) ≈ T_celsius[m] + 273.15 rtol = error_tolerance
        end
    end

    ll = LatLon(45, 10)
    annual = ItuRP1510.surfacemeantemperature(ll)
    monthly_mean = sum(m -> ItuRP1510.surfacemeantemperature(ll, m) * (31, 28.25, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[m], 1:12) / 365.25
    @test annual ≈ monthly_mean rtol = 1e-3
    @test ItuRP1510.surfacemeantemperature(45, 10, 3) == ItuRP1510.surfacemeantemperature(ll, 3)
    @test_throws "between 1 and 12" ItuRP1510.surfacemeantemperature(ll, 13)
    @test @allocated(ItuRP1510.surfacemeantemperature(ll)) == 0
    @test @allocated(ItuRP1510.surfacemeantemperature(ll, 7)) == 0
end
