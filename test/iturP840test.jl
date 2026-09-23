@testitem "P.840-9 - Attenuation due to clouds and fog" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P.840-9 A_Clouds")
        map(eachrow(sheet["C21:M52"])) do row
            ll = LatLon(row[1], row[2])
            p = row[3]
            f = row[4]
            el = row[5]
            K = (;
                ϵ′=row[6],
                ϵ′′=row[7],
                η=row[8],
                K_L=row[9],
            )
            L = row[10]
            Ac = row[11]
            (; ll, p, f, el, K, L, Ac)
        end
    end
    for entry in entries
        (; ll, p, f, el, L, Ac) = entry
        out = ItuRP840._K_L(f)
        @test all(propertynames(entry.K)) do fld
            validation = getproperty(entry.K, fld)
            computed = getproperty(out, fld)
            valid = isapprox(computed, validation; rtol=error_tolerance)
            if !valid
                @warn "Kₗ entry $ll, $fld: $computed != $validation"
            end
            valid
        end
        @test ItuRP840.liquidwatercontent(ll, p) ≈ L rtol = error_tolerance
        @test ItuRP840.cloudattenuation(ll, f, el, p) ≈ Ac rtol = error_tolerance
    end
end

@testitem "P.840-9 - Liquid Water Content Interpolation" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P840_9_L")
        map(eachrow(sheet["C24:G59"])) do row
            (;
                ll=LatLon(row[1], row[2]),
                p=row[3],   
                L=row[5],
            )
        end
    end
    for entry in entries
        (; ll, p, L) = entry
        @test ItuRP840.liquidwatercontent(ll, p) ≈ L rtol = error_tolerance
    end
end

@testitem "P.840-9 - Log-normal cloud attenuation" setup = [setup_common] begin
    entries = XLSX.openxlsx(validation_file) do wb
        sheet = XLSX.getsheet(wb, "P.840-9 A_Clouds")
        map(eachrow(sheet["O21:Z52"])) do row
            (;
                ll = LatLon(row[1], row[2]),
                p = row[3],
                f = row[4],
                el = row[5],
                K_L = row[6],
                mL = row[7],
                sL = row[8],
                PL = row[9],
                lognormal_term = row[10],
                Ac_zenith = row[11],
                Ac = row[12],
            )
        end
    end
    @test length(entries) == 32
    # Both branches of equation 15 and a location without approximation (the sheet's zero mL and sL) are covered by the sheet
    @test any(e -> e.p >= e.PL, entries)
    @test any(e -> e.p < e.PL, entries)
    @test any(e -> e.mL == 0, entries)
    for entry in entries
        (; ll, p, f, el) = entry
        out = ItuRP840._cloudattenuation_lognormal(ll, f, el, p)
        for fld in (:K_L, :PL, :Ac_zenith, :Ac)
            @test getproperty(out, fld) ≈ getproperty(entry, fld) rtol = error_tolerance
        end
        if isnan(out.mL)
            # The sheet writes 0 for mL and sL where the maps define no approximation, and the attenuation is zero there
            @test isnan(out.sL)
            @test entry.mL == entry.sL == 0
            @test entry.Ac == 0
        else
            @test out.mL ≈ entry.mL rtol = error_tolerance
            @test out.sL ≈ entry.sL rtol = error_tolerance
        end
        # The sheet fills the log-normal term with a placeholder when p ≥ PL, where equation 15 does not use it
        p < entry.PL && @test out.lognormal_term ≈ entry.lognormal_term rtol = error_tolerance
        @test ItuRP840.cloudattenuation_lognormal(ll, f, el, p) == out.Ac
        @test ItuRP840.lognormalparameters(ll) === (; mL = out.mL, sL = out.sL, PL = out.PL)
    end

    # Section 3.3, note: no attenuation where the probability of cloud is at most 0.02 % at a surrounding grid point; the maps hold NaN for mL and sL there
    pole = LatLon(-89.9, 0)
    @test isnan(ItuRP840.lognormalparameters(pole).mL)
    @test ItuRP840.cloudattenuation_lognormal(pole, 30, 45, 1) == 0
    # The maps hold NaN for mL and sL together, and only where PL is at most 0.02 % (a handful of grid points sit exactly at 0.02 % on one side of that split or the other); the guard's `<=` is the conservative superset that keeps every NaN out of equation 15
    mL_itp, sL_itp, PL_itp = ItuRP840.ANNUAL_DATA.lognormal
    @test isnan.(mL_itp.data) == isnan.(sL_itp.data)
    @test all(isnan.(mL_itp.data) .<= (PL_itp.data .<= 0.02))
    @test !any(isnan, PL_itp.data)
    # Grid edges: the poles and the antimeridian resolve to a degenerate stencil rather than an out-of-range index
    @test isnan(ItuRP840.lognormalparameters(LatLon(-90, 180)).mL)
    @test ItuRP840.cloudattenuation_lognormal(LatLon(-90, 180), 30, 45, 1) == 0
    @test ItuRP840.lognormalparameters(LatLon(45, -180)).PL == ItuRP840.lognormalparameters(LatLon(45, 180)).PL
    # p at or above the probability of cloud
    @test ItuRP840.cloudattenuation_lognormal(0, 0, 30, 45, 99) == 0

    ll = LatLon(45.3, 9.7)
    @test ItuRP840.cloudattenuation_lognormal(45.3, 9.7, 30, 45, 1) == ItuRP840.cloudattenuation_lognormal(ll, 30, 45, 1)
    @test ItuRP840.lognormalparameters(45.3, 9.7) === ItuRP840.lognormalparameters(ll)
    @test ItuRP840.cloudattenuation_lognormal(ll, 30, 45, 1) > ItuRP840.cloudattenuation_lognormal(ll, 30, 45, 10) > 0
    @test allocations(ItuRP840.cloudattenuation_lognormal, ll, 30.0, 45.0, 1.0) == 0
    @test allocations(ItuRP840.lognormalparameters, ll) == 0
    @test_logs (:warn, r"between 5 and 90 degrees") match_mode=:any ItuRP840.cloudattenuation_lognormal(ll, 30, 1, 1)
    @test_logs (:warn, r"between 1 and 200 GHz") match_mode=:any ItuRP840.cloudattenuation_lognormal(ll, 1000, 45, 1)
    @test_logs ItuRP840.cloudattenuation_lognormal(ll, 1000, 1, 1; warn = false)
    @test_throws "within (0, 100]" ItuRP840.cloudattenuation_lognormal(ll, 30, 45, 0)
    @test_throws "within (0, 100]" ItuRP840.cloudattenuation_lognormal(ll, 30, 45, -1)
    @test_throws "within (0, 100]" ItuRP840.cloudattenuation_lognormal(ll, 30, 45, 101)
end
