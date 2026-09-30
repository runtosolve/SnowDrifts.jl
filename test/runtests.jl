using SnowDrifts
using Test

@testset "SnowDrifts.jl" begin

    @testset "snow_density (Eq. 7.7-1)" begin
        @test SnowDrifts.snow_density(30) ≈ 17.9
        @test SnowDrifts.snow_density(200) == 30.0  # capped
        @test_throws ArgumentError SnowDrifts.snow_density(-1)
    end

    @testset "balanced_snow_height" begin
        @test SnowDrifts.balanced_snow_height(16.8, 17.9; design_code="LRFD") ≈ 16.8 / 17.9
    end

    @testset "drift_height (Eq. 7.6-1, ASCE 7-22) vs. Commentary Example 1" begin
        # pg=30, W2=0.55, lu=30 (6-on-12, S=2.0) -> γ=17.9 pcf, hd=2.46 ft.
        γ = SnowDrifts.snow_density(30)
        @test γ ≈ 17.9
        hd = SnowDrifts.drift_height(30, 30, γ; W2=0.55)
        @test hd ≈ 2.46 atol=0.01

        @test_throws ArgumentError SnowDrifts.drift_height(-1, 30, γ; W2=0.55)
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; W2=-1)
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ)   # W2 required
    end

    @testset "drift_height (Fig. 7.6-1, ASCE 7-16) vs. C7.6 Example 1" begin
        # Same pg=30, lu=30, Is=1.0 (Risk Cat II) -> hd=1.86 ft.
        γ = SnowDrifts.snow_density(30)
        hd = SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16, Is=1.0)
        @test hd ≈ 1.86 atol=0.01

        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16)  # Is required
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16, Is=-1)

        # lu < 20 ft: floored to 20 ft, then capped at sqrt(Is*pg*lu/(4γ)) using actual lu.
        pg, lu, Is = 5.0, 5.0, 1.0
        γ2 = SnowDrifts.snow_density(pg)
        hd_floored = sqrt(Is) * (0.43 * 20.0^(1 / 3) * (pg + 10)^(1 / 4) - 1.5)
        hd_cap = sqrt(Is * pg * lu / (4γ2))
        @test hd_cap < hd_floored
        @test SnowDrifts.drift_height(pg, lu, γ2; standard=:ASCE7_16, Is=Is) ≈ hd_cap
    end

    @testset "unbalanced_gable_hip_surcharge vs. ASCE 7-22 Commentary Example 1" begin
        # Same example: intensity ≈ 31.1 psf, extent ≈ 9.3 ft.
        γ = SnowDrifts.snow_density(30)
        result = SnowDrifts.unbalanced_gable_hip_surcharge(30, 0.55, γ, 30, 2.0; design_code="LRFD")
        @test result.pd ≈ 31.1 atol=0.3
        @test result.w ≈ 9.3 atol=0.1
    end

    @testset "unbalanced_gable_hip_surcharge, ASCE 7-16 path" begin
        γ = SnowDrifts.snow_density(30)
        result = SnowDrifts.unbalanced_gable_hip_surcharge(30, NaN, γ, 30, 2.0;
                                                             standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test result.hd ≈ 1.86 atol=0.01
        @test result.pd ≈ 1.86 * γ / sqrt(2.0) atol=0.05
        @test result.w ≈ (8 / 3) * 1.86 * sqrt(2.0) atol=0.05
    end

    @testset "requires_drift_load" begin
        @test SnowDrifts.requires_drift_load(1.0, 2.0) == true    # hc/hb = 0.5
        @test SnowDrifts.requires_drift_load(0.1, 2.0) == false   # hc/hb = 0.05
        @test SnowDrifts.requires_drift_load(0.4, 2.0) == true    # hc/hb = 0.2, boundary
    end

    @testset "leeward_drift (ASCE 7-22 only)" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        lu = 100.0

        hc = 20.0   # not capped
        d = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; design_code="LRFD")
        hd_raw = SnowDrifts.drift_height(pg, lu, γ; W2=W2)
        @test d.hd ≈ hd_raw
        @test d.w ≈ 4 * hd_raw
        @test d.pd ≈ d.hd * γ

        hc_small = hd_raw / 2   # capped: width formula switches
        d2 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc_small; design_code="LRFD")
        @test d2.hd ≈ hc_small
        @test d2.w ≈ min(4 * hd_raw^2 / hc_small, 8 * hc_small)

        d3 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=1.0, design_code="LRFD")
        @test d3.hd_raw ≈ 0.6   # 60%-of-lower-roof-length cap

        d4 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; roof_width=1.0, design_code="LRFD")
        @test d4.w ≈ 1.0   # roof_width truncation

        @test_throws ArgumentError SnowDrifts.leeward_drift(pg, W2, γ, lu, hc;
                                                              design_code="LRFD", standard=:ASCE7_16)
    end

    @testset "windward_drift (ASCE 7-22 only)" begin
        pg, W2 = 32.0, 0.5
        γ = SnowDrifts.snow_density(pg)
        lu = 240.0
        d = SnowDrifts.windward_drift(pg, W2, γ, lu; design_code="LRFD")
        hd_raw = SnowDrifts.drift_height(pg, lu, γ; W2=W2)
        @test d.hd ≈ 0.75 * hd_raw
        @test d.w ≈ 8 * d.hd ≈ 6 * hd_raw
        @test d.pd ≈ d.hd * γ

        d2 = SnowDrifts.windward_drift(pg, W2, γ, lu; roof_width=5.0, design_code="LRFD")
        @test d2.w ≈ 5.0

        @test_throws ArgumentError SnowDrifts.windward_drift(pg, W2, γ, lu;
                                                               design_code="LRFD", standard=:ASCE7_16)
    end

    @testset "roof_step_drift, ASCE 7-22 (independent leeward/windward)" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        hb, hc = 1.0, 0.05  # hc/hb = 0.05 < 0.2
        r = SnowDrifts.roof_step_drift(pg, W2, γ, hb, hc, 100.0, 50.0; design_code="LRFD")
        @test r.required == false

        hc2 = 5.0
        r2 = SnowDrifts.roof_step_drift(pg, W2, γ, hb, hc2, 100.0, 50.0; design_code="LRFD")
        @test r2.required == true
        @test r2.governing in (:leeward, :windward)
        @test r2.leeward !== r2.windward  # independent geometries in ASCE 7-22
    end

    @testset "roof_step_drift, ASCE 7-16 (coupled leeward/windward) vs. C7.7 Example 3" begin
        # pg=40, Is=1.0, elevation diff 10 ft, hb=1.4, hc=8.6 (hc/hb=6.1, required).
        # Upper roof 100 ft, lower roof 170 ft. Leeward governs (hd < hc): hd=3.8,
        # w=4hd≈15.2, pd=hd*γ≈72 (commentary rounds γ to 19; exact γ=19.2 here).
        pg, Is = 40.0, 1.0
        γ = SnowDrifts.snow_density(pg)
        @test γ ≈ 19.2
        hb, hc = 1.4, 8.6
        r = SnowDrifts.roof_step_drift(pg, NaN, γ, hb, hc, 100.0, 170.0;
                                        lower_roof_length=170.0, standard=:ASCE7_16,
                                        Is=Is, design_code="LRFD")
        @test r.required == true
        @test r.governing == :leeward
        @test r.leeward === r.windward   # ASCE 7-16: one shared design drift
        @test r.leeward.hd ≈ 3.8 atol=0.02
        @test r.leeward.w ≈ 15.2 atol=0.1
        @test r.leeward.pd ≈ 72 atol=1.5

        # Much longer windward fetch should flip the governing direction.
        r2 = SnowDrifts.roof_step_drift(pg, NaN, γ, hb, hc, 20.0, 600.0;
                                         lower_roof_length=600.0, standard=:ASCE7_16,
                                         Is=Is, design_code="LRFD")
        @test r2.governing == :windward

        @test_throws ArgumentError SnowDrifts.roof_step_drift(pg, NaN, γ, hb, hc, 100.0, 170.0;
                                                                standard=:ASCE7_16, design_code="LRFD")  # Is required
    end

    @testset "roof_step_drift: ASCE 7-22 windward is NOT hc-capped but ASCE 7-16's is" begin
        pg = 40.0
        γ = SnowDrifts.snow_density(pg)
        hb, hc = 0.5, 1.0
        lu_upper, lu_lower = 20.0, 600.0   # raw windward height will exceed hc

        r22 = SnowDrifts.roof_step_drift(pg, 0.45, γ, hb, hc, lu_upper, lu_lower; design_code="LRFD")
        @test r22.windward.hd_raw > hc
        @test r22.windward.hd ≈ 0.75 * r22.windward.hd_raw   # uncapped
        @test r22.windward.hd > hc

        r16 = SnowDrifts.roof_step_drift(pg, NaN, γ, hb, hc, lu_upper, lu_lower;
                                          standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test r16.windward.hd ≈ hc   # capped
    end

    @testset "adjacent_structure_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        lu, h, s = 100.0, 15.0, 10.0  # s < 20 and s < 6h=90: OK
        d = SnowDrifts.adjacent_structure_drift(pg, W2, γ, lu, h, s; design_code="LRFD")
        @test d.hd <= (6 * h - s) / 6 + 1e-9
        @test d.w <= 6 * h - s + 1e-9

        hd_raw = SnowDrifts.drift_height(pg, lu, γ; W2=W2)
        if hd_raw <= (6 * h - s) / 6
            @test d.w ≈ 6 * hd_raw   # width is 6*hd, not 4*hd
        end

        @test_throws ArgumentError SnowDrifts.adjacent_structure_drift(pg, W2, γ, lu, 1.0, 20.0; design_code="LRFD")

        d16 = SnowDrifts.adjacent_structure_drift(pg, NaN, γ, lu, h, s;
                                                   standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test d16 isa SnowDrifts.DriftLoad
    end

    @testset "parapet_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        d = SnowDrifts.parapet_drift(pg, W2, γ, 80.0; design_code="LRFD")
        @test d.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 80.0, γ; W2=W2)

        d16 = SnowDrifts.parapet_drift(pg, NaN, γ, 80.0; standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test d16.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 80.0, γ; standard=:ASCE7_16, Is=1.0)
    end

    @testset "roof_projection_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)

        r = SnowDrifts.roof_projection_drift(pg, W2, γ, 40.0, 20.0, 10.0, 0.5; design_code="LRFD")
        @test r.required == false && r.drift === nothing   # short side

        r2 = SnowDrifts.roof_projection_drift(pg, W2, γ, 40.0, 20.0, 20.0, 2.5; design_code="LRFD")
        @test r2.required == false   # ample clearance

        r3 = SnowDrifts.roof_projection_drift(pg, W2, γ, 40.0, 20.0, 20.0, 0.5; design_code="LRFD")
        @test r3.required == true
        @test r3.drift.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 40.0, γ; W2=W2)  # lu = max(upwind, downwind)

        r16 = SnowDrifts.roof_projection_drift(pg, NaN, γ, 40.0, 20.0, 20.0, 0.5;
                                                standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test r16.drift.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 40.0, γ; standard=:ASCE7_16, Is=1.0)
    end

    @testset "design_code factoring (ASD = 0.7, LRFD = 1.0)" begin
        @test SnowDrifts.snow_load_factor("ASD") == 0.7
        @test SnowDrifts.snow_load_factor("LRFD") == 1.0
        @test_throws ArgumentError SnowDrifts.snow_load_factor("LSD")
        @test_throws UndefKeywordError SnowDrifts.windward_drift(110, 0.35, 28.3, 100.0)  # design_code required

        γ = SnowDrifts.snow_density(110)
        ps_lrfd = 48.51 / 0.7
        @test SnowDrifts.balanced_snow_height(0.7 * ps_lrfd, γ; design_code="ASD") ≈
              SnowDrifts.balanced_snow_height(ps_lrfd, γ; design_code="LRFD")
        @test SnowDrifts.snow_load_factor(:ASD) == 0.7

        for f in (
            dc -> SnowDrifts.leeward_drift(110, 0.35, γ, 100.0, 20.0; design_code=dc),
            dc -> SnowDrifts.windward_drift(110, 0.35, γ, 100.0; design_code=dc),
            dc -> SnowDrifts.adjacent_structure_drift(110, 0.35, γ, 100.0, 15.0, 10.0; design_code=dc),
            dc -> SnowDrifts.parapet_drift(110, 0.35, γ, 80.0; design_code=dc),
            dc -> SnowDrifts.unbalanced_gable_hip_surcharge(110, 0.35, γ, 30.0, 2.0; design_code=dc),
        )
            a, l = f("ASD"), f("LRFD")
            @test a.pd ≈ 0.7 * l.pd
            @test a.hd == l.hd && a.w == l.w && a.hd_raw == l.hd_raw
        end

        step_a = SnowDrifts.roof_step_drift(110, 0.35, γ, 3.0, 8.9, 285.0, 285.0; design_code="ASD")
        step_l = SnowDrifts.roof_step_drift(110, 0.35, γ, 3.0, 8.9, 285.0, 285.0; design_code="LRFD")
        @test step_a.leeward.pd ≈ 0.7 * step_l.leeward.pd
        @test step_a.governing == step_l.governing && step_a.required == step_l.required
    end

    @testset "design standard input (same STANDARDS list as SnowLoads.jl)" begin
        @test SnowDrifts.standard_name(:ASCE7_22) == "ASCE/SEI 7-22 (USA)"
        @test SnowDrifts.standard_name(:ASCE7_16) == "ASCE/SEI 7-16 (USA)"
        @test SnowDrifts.drift_height(110, 100.0, 28.3; W2=0.35) ==
              SnowDrifts.drift_height(110, 100.0, 28.3; standard=:ASCE7_22, W2=0.35)
        @test SnowDrifts.drift_height(110, 100.0, 28.3; standard=:ASCE7_16, Is=1.0) isa Float64

        @test_throws ErrorException SnowDrifts.snow_density(110; standard=:NBCC_2020)
        @test_throws ErrorException SnowDrifts.drift_height(110, 100.0, 28.3; standard=:EN1991_1_3, W2=0.35)
        @test_throws ErrorException SnowDrifts.windward_drift(110, 0.35, 28.3, 100.0;
                                                                design_code="ASD", standard=:ASCE7_10)
        @test_throws ErrorException SnowDrifts.roof_step_drift(110, 0.35, 28.3, 2.4, 8.9, 25.0, 130.0;
                                                                 design_code="ASD", standard=:AS_NZS_1170)
        @test_throws ErrorException SnowDrifts.unbalanced_gable_hip_surcharge(110, 0.35, 28.3, 12.5, 4.0;
                                                                                design_code="ASD", standard=:OTHER)
        @test_throws ArgumentError SnowDrifts.snow_density(110; standard=:NOPE)   # unknown key
    end

end
