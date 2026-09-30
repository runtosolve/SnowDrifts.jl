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
        # C7.6 Example 1: pg = 30 psf, W2 = 0.55, W = lu = 30 ft (6-on-12
        # gable, S = 2.0). Commentary reports γ = 17.9 pcf and hd = 2.46 ft.
        γ = SnowDrifts.snow_density(30)
        @test γ ≈ 17.9
        hd = SnowDrifts.drift_height(30, 30, γ; W2=0.55)
        @test hd ≈ 2.46 atol=0.01

        @test_throws ArgumentError SnowDrifts.drift_height(-1, 30, γ; W2=0.55)
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; W2=-1)
        # standard=:ASCE7_22 requires W2
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ)
    end

    @testset "drift_height (Fig. 7.6-1, ASCE 7-16) vs. C7.6 Example 1" begin
        # ASCE 7-16 Commentary C7.6 Example 1: same pg = 30 psf, lu = 30 ft,
        # Is = 1.0 (Risk Category II). Reports hd = 1.86 ft (no W2 in 7-16).
        γ = SnowDrifts.snow_density(30)
        hd = SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16, Is=1.0)
        @test hd ≈ 1.86 atol=0.01

        # standard=:ASCE7_16 requires Is, not W2
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16)
        @test_throws ArgumentError SnowDrifts.drift_height(30, 30, γ; standard=:ASCE7_16, Is=-1)

        # lu < 20 ft: floored to 20 ft in the main relation, then capped at
        # sqrt(Is*pg*lu/(4γ)) using the ACTUAL (unfloored) lu. Case where the
        # small-fetch cap governs (very low pg, lu):
        pg, lu, Is = 5.0, 5.0, 1.0
        γ2 = SnowDrifts.snow_density(pg)
        hd_floored = sqrt(Is) * (0.43 * 20.0^(1 / 3) * (pg + 10)^(1 / 4) - 1.5)
        hd_cap = sqrt(Is * pg * lu / (4γ2))
        @test hd_cap < hd_floored   # confirms this case is the one the cap is for
        @test SnowDrifts.drift_height(pg, lu, γ2; standard=:ASCE7_16, Is=Is) ≈ hd_cap

        # The mandatory lu >= 20 ft floor (applied before the small-fetch cap
        # above) keeps the bracket positive for any pg > 0, so the defensive
        # max(hd, 0) clamp in the implementation is not ordinarily reachable
        # through this code path — it guards the formula itself, not this floor.
        @test SnowDrifts.drift_height(0.01, 20.0, SnowDrifts.snow_density(0.01);
                                       standard=:ASCE7_16, Is=0.8) > 0
    end

    @testset "unbalanced_gable_hip_surcharge vs. ASCE 7-22 Commentary Example 1" begin
        # Same example: intensity hd γ / sqrt(S) ≈ 31.1 psf, extent
        # (8/3) hd sqrt(S) ≈ 9.3 ft.
        γ = SnowDrifts.snow_density(30)
        result = SnowDrifts.unbalanced_gable_hip_surcharge(30, γ, 30, 2.0; W2=0.55, design_code="LRFD")
        @test result.pd ≈ 31.1 atol=0.3
        @test result.w ≈ 9.3 atol=0.1
    end

    @testset "unbalanced_gable_hip_surcharge, ASCE 7-16 path" begin
        γ = SnowDrifts.snow_density(30)
        result = SnowDrifts.unbalanced_gable_hip_surcharge(30, γ, 30, 2.0;
                                                             standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        # hd = 1.86 ft (verified above); pd = hd γ / sqrt(S), w = (8/3) hd sqrt(S).
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

        # Case: hc large enough that hd is not capped.
        hc = 20.0
        d = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; design_code="LRFD")
        hd_raw = SnowDrifts.drift_height(pg, lu, γ; W2=W2)
        @test d.hd ≈ hd_raw
        @test d.w ≈ 4 * hd_raw
        @test d.pd ≈ d.hd * γ

        # Case: hc small enough to cap the drift, switching the width formula.
        hc_small = hd_raw / 2
        d2 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc_small; design_code="LRFD")
        @test d2.hd ≈ hc_small
        @test d2.w ≈ min(4 * hd_raw^2 / hc_small, 8 * hc_small)

        # 60%-of-lower-roof-length cap.
        d3 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=1.0, design_code="LRFD")
        @test d3.hd_raw ≈ 0.6

        # roof_width truncation.
        d4 = SnowDrifts.leeward_drift(pg, W2, γ, lu, hc; roof_width=1.0, design_code="LRFD")
        @test d4.w ≈ 1.0

        # Rejects standards other than :ASCE7_22.
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
        @test d.w ≈ 8 * d.hd
        @test d.w ≈ 6 * hd_raw
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
        r = SnowDrifts.roof_step_drift(pg, γ, hb, hc, 100.0, 50.0; W2=W2, design_code="LRFD")
        @test r.required == false

        hc2 = 5.0
        r2 = SnowDrifts.roof_step_drift(pg, γ, hb, hc2, 100.0, 50.0; W2=W2, design_code="LRFD")
        @test r2.required == true
        @test r2.governing in (:leeward, :windward)
        @test r2.leeward isa SnowDrifts.DriftLoad
        @test r2.windward isa SnowDrifts.DriftLoad
        @test r2.leeward !== r2.windward  # independent geometries in ASCE 7-22
    end

    @testset "roof_step_drift, ASCE 7-16 (coupled leeward/windward) vs. C7.7 Example 3" begin
        # ASCE 7-16 Commentary C7.7 Example 3: pg = 40 psf, Is = 1.0. Elevation
        # difference 10 ft, hb = 1.4 ft, hc = 8.6 ft (hc/hb = 6.1, drift
        # required). Upper (leeward-fetch) roof 100 ft; lower roof 170 ft
        # wide (also lower_roof_length and the windward fetch). Commentary:
        # hd(leeward) = 3.8 ft, hd(windward, raw) = 0.75*4.8 = 3.6 ft, leeward
        # governs (hd < hc so uncapped), w = 4hd ≈ 15.2 ft, pd = hd*γ ≈ 72 psf
        # (commentary rounds γ to 19 pcf; exact γ = 19.2 pcf here).
        pg, Is = 40.0, 1.0
        γ = SnowDrifts.snow_density(pg)
        @test γ ≈ 19.2
        hb, hc = 1.4, 8.6
        r = SnowDrifts.roof_step_drift(pg, γ, hb, hc, 100.0, 170.0;
                                        lower_roof_length=170.0, standard=:ASCE7_16,
                                        Is=Is, design_code="LRFD")
        @test r.required == true
        @test r.governing == :leeward
        @test r.leeward === r.windward   # ASCE 7-16: one shared design drift
        @test r.leeward.hd ≈ 3.8 atol=0.02
        @test r.leeward.w ≈ 15.2 atol=0.1
        @test r.leeward.pd ≈ 72 atol=1.5

        # Sanity: if the lower/windward fetch is made much longer than the
        # upper/leeward fetch, windward should govern instead.
        r2 = SnowDrifts.roof_step_drift(pg, γ, hb, hc, 20.0, 600.0;
                                         lower_roof_length=600.0, standard=:ASCE7_16,
                                         Is=Is, design_code="LRFD")
        @test r2.governing == :windward

        # standard=:ASCE7_16 requires Is
        @test_throws ArgumentError SnowDrifts.roof_step_drift(pg, γ, hb, hc, 100.0, 170.0;
                                                                standard=:ASCE7_16, design_code="LRFD")
    end

    @testset "roof_step_drift: same geometry, ASCE 7-22 windward is NOT hc-capped but ASCE 7-16's is" begin
        # Construct a case where the raw windward height exceeds hc: ASCE
        # 7-22 should leave the windward height uncapped (its own DriftLoad,
        # independent of leeward); ASCE 7-16 should cap whichever of the two
        # raw heights is larger.
        pg = 40.0
        γ = SnowDrifts.snow_density(pg)
        hb, hc = 0.5, 1.0   # small hc so windward (raw, large lu_lower) exceeds it
        lu_upper, lu_lower = 20.0, 600.0

        r22 = SnowDrifts.roof_step_drift(pg, γ, hb, hc, lu_upper, lu_lower; W2=0.45, design_code="LRFD")
        @test r22.windward.hd_raw > hc
        @test r22.windward.hd ≈ 0.75 * r22.windward.hd_raw   # always 0.75x raw, uncapped by hc
        @test r22.windward.hd > hc                           # ... even though that exceeds hc
        @test r22.windward.w ≈ 8 * r22.windward.hd

        r16 = SnowDrifts.roof_step_drift(pg, γ, hb, hc, lu_upper, lu_lower;
                                          standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test r16.windward.hd_raw > hc
        @test r16.windward.hd ≈ hc   # capped in ASCE 7-16
    end

    @testset "adjacent_structure_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        lu, h, s = 100.0, 15.0, 10.0  # s < 20 and s < 6h=90: OK
        d = SnowDrifts.adjacent_structure_drift(pg, lu, γ, h, s; W2=W2, design_code="LRFD")
        @test d.hd <= (6 * h - s) / 6 + 1e-9
        @test d.w <= 6 * h - s + 1e-9

        # Not capped by hc (none applies here): width is 6*hd, not 4*hd.
        hd_raw = SnowDrifts.drift_height(pg, lu, γ; W2=W2)
        if hd_raw <= (6 * h - s) / 6
            @test d.w ≈ 6 * hd_raw
        end

        @test_throws ArgumentError SnowDrifts.adjacent_structure_drift(pg, lu, γ, 1.0, 20.0;
                                                                         W2=W2, design_code="LRFD")

        # ASCE 7-16 path (shares the same formula structure, different drift_height).
        d16 = SnowDrifts.adjacent_structure_drift(pg, lu, γ, h, s;
                                                   standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test d16 isa SnowDrifts.DriftLoad
    end

    @testset "parapet_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)
        d = SnowDrifts.parapet_drift(pg, γ, 80.0; W2=W2, design_code="LRFD")
        @test d isa SnowDrifts.DriftLoad
        @test d.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 80.0, γ; W2=W2)

        d16 = SnowDrifts.parapet_drift(pg, γ, 80.0; standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test d16.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 80.0, γ; standard=:ASCE7_16, Is=1.0)
    end

    @testset "roof_projection_drift" begin
        pg, W2 = 30.0, 0.55
        γ = SnowDrifts.snow_density(pg)

        # Exception: short side.
        r = SnowDrifts.roof_projection_drift(pg, γ, 40.0, 20.0, 10.0, 0.5; W2=W2, design_code="LRFD")
        @test r.required == false
        @test r.drift === nothing

        # Exception: ample clearance.
        r2 = SnowDrifts.roof_projection_drift(pg, γ, 40.0, 20.0, 20.0, 2.5; W2=W2, design_code="LRFD")
        @test r2.required == false

        # Drift required; lu is the larger of upwind/downwind lengths.
        r3 = SnowDrifts.roof_projection_drift(pg, γ, 40.0, 20.0, 20.0, 0.5; W2=W2, design_code="LRFD")
        @test r3.required == true
        @test r3.drift.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 40.0, γ; W2=W2)

        r16 = SnowDrifts.roof_projection_drift(pg, γ, 40.0, 20.0, 20.0, 0.5;
                                                standard=:ASCE7_16, Is=1.0, design_code="LRFD")
        @test r16.required == true
        @test r16.drift.hd ≈ 0.75 * SnowDrifts.drift_height(pg, 40.0, γ; standard=:ASCE7_16, Is=1.0)
    end

    @testset "design_code factoring (ASD = 0.7, LRFD = 1.0)" begin
        @test SnowDrifts.snow_load_factor("ASD") == 0.7
        @test SnowDrifts.snow_load_factor("LRFD") == 1.0
        @test_throws ArgumentError SnowDrifts.snow_load_factor("LSD")
        # design_code is required
        @test_throws UndefKeywordError SnowDrifts.windward_drift(110, 0.35, 28.3, 100.0)

        # hb un-factors the (already factored) ps it is given: same geometry for both codes
        γ = SnowDrifts.snow_density(110)
        ps_lrfd = 48.51 / 0.7      # strength-level balanced load
        @test SnowDrifts.balanced_snow_height(0.7 * ps_lrfd, γ; design_code="ASD") ≈
              SnowDrifts.balanced_snow_height(ps_lrfd, γ; design_code="LRFD")
        @test SnowDrifts.snow_load_factor(:ASD) == 0.7      # Symbol accepted too

        for f in (
            dc -> SnowDrifts.leeward_drift(110, 0.35, γ, 100.0, 20.0; design_code=dc),
            dc -> SnowDrifts.windward_drift(110, 0.35, γ, 100.0; design_code=dc),
            dc -> SnowDrifts.adjacent_structure_drift(110, 100.0, γ, 15.0, 10.0; W2=0.35, design_code=dc),
            dc -> SnowDrifts.parapet_drift(110, γ, 80.0; W2=0.35, design_code=dc),
            dc -> SnowDrifts.unbalanced_gable_hip_surcharge(110, γ, 30.0, 2.0; W2=0.35, design_code=dc),
        )
            a, l = f("ASD"), f("LRFD")
            @test a.pd ≈ 0.7 * l.pd
            @test a.hd == l.hd && a.w == l.w && a.hd_raw == l.hd_raw
        end

        step_a = SnowDrifts.roof_step_drift(110, γ, 3.0, 8.9, 285.0, 285.0; W2=0.35, design_code="ASD")
        step_l = SnowDrifts.roof_step_drift(110, γ, 3.0, 8.9, 285.0, 285.0; W2=0.35, design_code="LRFD")
        @test step_a.leeward.pd ≈ 0.7 * step_l.leeward.pd
        @test step_a.windward.pd ≈ 0.7 * step_l.windward.pd
        @test step_a.governing == step_l.governing && step_a.required == step_l.required

        proj_a = SnowDrifts.roof_projection_drift(110, γ, 40.0, 20.0, 20.0, 0.5; W2=0.35, design_code="ASD")
        proj_l = SnowDrifts.roof_projection_drift(110, γ, 40.0, 20.0, 20.0, 0.5; W2=0.35, design_code="LRFD")
        @test proj_a.drift.pd ≈ 0.7 * proj_l.drift.pd
    end

    @testset "design standard input (same STANDARDS list as SnowLoads.jl)" begin
        @test SnowDrifts.standard_name(:ASCE7_22) == "ASCE/SEI 7-22 (USA)"
        @test SnowDrifts.standard_name(:ASCE7_16) == "ASCE/SEI 7-16 (USA)"
        # default and explicit :ASCE7_22 agree
        @test SnowDrifts.drift_height(110, 100.0, 28.3; W2=0.35) ==
              SnowDrifts.drift_height(110, 100.0, 28.3; standard=:ASCE7_22, W2=0.35)
        # both implemented standards actually compute (no error)
        @test SnowDrifts.drift_height(110, 100.0, 28.3; standard=:ASCE7_16, Is=1.0) isa Float64
        # registered but not implemented -> clear error from every entry point
        @test_throws ErrorException SnowDrifts.snow_density(110; standard=:NBCC_2020)
        @test_throws ErrorException SnowDrifts.drift_height(110, 100.0, 28.3; standard=:EN1991_1_3, W2=0.35)
        @test_throws ErrorException SnowDrifts.windward_drift(110, 0.35, 28.3, 100.0;
                                                                design_code="ASD", standard=:ASCE7_10)
        @test_throws ErrorException SnowDrifts.roof_step_drift(110, 28.3, 2.4, 8.9, 25.0, 130.0;
                                                                 W2=0.35, design_code="ASD", standard=:AS_NZS_1170)
        @test_throws ErrorException SnowDrifts.unbalanced_gable_hip_surcharge(110, 28.3, 12.5, 4.0;
                                                                                W2=0.35, design_code="ASD", standard=:OTHER)
        # unknown key
        @test_throws ArgumentError SnowDrifts.snow_density(110; standard=:NOPE)
    end

end
