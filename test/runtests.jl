using SnowDrifts
using Test

@testset "SnowDrifts.jl" begin

    @testset "snow_density (Eq. 7.7-1)" begin
        @test snow_density(30) ≈ 17.9
        @test snow_density(200) == 30.0  # capped
        @test_throws ArgumentError snow_density(-1)
    end

    @testset "flat/sloped roof snow loads (Eq. 7.3-1, 7.4-1)" begin
        @test flat_roof_snow_load(30) ≈ 21.0
        @test flat_roof_snow_load(30; Ce=0.9, Ct=1.1) ≈ 0.7 * 0.9 * 1.1 * 30
        @test sloped_roof_snow_load(21.0, 0.8) ≈ 16.8
    end

    @testset "balanced_snow_height" begin
        @test balanced_snow_height(16.8, 17.9) ≈ 16.8 / 17.9
    end

    @testset "minimum_snow_load (Table 7.3-4)" begin
        @test minimum_snow_load(10, :II) == 10
        @test minimum_snow_load(50, :II) == 30
        @test_throws ArgumentError minimum_snow_load(10, :V)
    end

    @testset "drift_height (Eq. 7.6-1) vs. ASCE 7-22 Commentary Example 1" begin
        # C7.6 Example 1: pg = 30 psf, W2 = 0.55, W = lu = 30 ft (6-on-12
        # gable, S = 2.0). Commentary reports γ = 17.9 pcf and hd = 2.46 ft.
        γ = snow_density(30)
        @test γ ≈ 17.9
        hd = drift_height(30, 30, 0.55, γ)
        @test hd ≈ 2.46 atol=0.01

        @test_throws ArgumentError drift_height(-1, 30, 0.55, γ)
        @test_throws ArgumentError drift_height(30, 30, -1, γ)
    end

    @testset "unbalanced_gable_hip_surcharge vs. Commentary Example 1" begin
        # Same example: intensity hd γ / sqrt(S) ≈ 31.1 psf, extent
        # (8/3) hd sqrt(S) ≈ 9.3 ft.
        γ = snow_density(30)
        result = unbalanced_gable_hip_surcharge(30, 0.55, γ, 30, 2.0)
        @test result.pd ≈ 31.1 atol=0.3
        @test result.w ≈ 9.3 atol=0.1
    end

    @testset "requires_drift_load" begin
        @test requires_drift_load(1.0, 2.0) == true    # hc/hb = 0.5
        @test requires_drift_load(0.1, 2.0) == false   # hc/hb = 0.05
        @test requires_drift_load(0.4, 2.0) == true    # hc/hb = 0.2, boundary
    end

    @testset "leeward_drift" begin
        pg, W2 = 30.0, 0.55
        γ = snow_density(pg)
        lu = 100.0

        # Case: hc large enough that hd is not capped.
        hc = 20.0
        d = leeward_drift(pg, W2, γ, lu, hc)
        hd_raw = drift_height(pg, lu, W2, γ)
        @test d.hd ≈ hd_raw
        @test d.w ≈ 4 * hd_raw
        @test d.pd ≈ d.hd * γ

        # Case: hc small enough to cap the drift, switching the width formula.
        hc_small = hd_raw / 2
        d2 = leeward_drift(pg, W2, γ, lu, hc_small)
        @test d2.hd ≈ hc_small
        @test d2.w ≈ min(4 * hd_raw^2 / hc_small, 8 * hc_small)

        # 60%-of-lower-roof-length cap.
        d3 = leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=1.0)
        @test d3.hd_raw ≈ 0.6

        # roof_width truncation.
        d4 = leeward_drift(pg, W2, γ, lu, hc; roof_width=1.0)
        @test d4.w ≈ 1.0
    end

    @testset "windward_drift" begin
        pg, W2 = 32.0, 0.5
        γ = snow_density(pg)
        lu = 240.0
        d = windward_drift(pg, W2, γ, lu)
        hd_raw = drift_height(pg, lu, W2, γ)
        @test d.hd ≈ 0.75 * hd_raw
        @test d.w ≈ 8 * d.hd
        @test d.w ≈ 6 * hd_raw
        @test d.pd ≈ d.hd * γ

        d2 = windward_drift(pg, W2, γ, lu; roof_width=5.0)
        @test d2.w ≈ 5.0
    end

    @testset "roof_step_drift" begin
        pg, W2 = 30.0, 0.55
        γ = snow_density(pg)
        hb, hc = 1.0, 0.05  # hc/hb = 0.05 < 0.2
        r = roof_step_drift(pg, W2, γ, hb, hc, 100.0, 50.0)
        @test r.required == false

        hc2 = 5.0
        r2 = roof_step_drift(pg, W2, γ, hb, hc2, 100.0, 50.0)
        @test r2.required == true
        @test r2.governing in (:leeward, :windward)
        @test r2.leeward isa DriftLoad
        @test r2.windward isa DriftLoad
    end

    @testset "adjacent_structure_drift" begin
        pg, W2 = 30.0, 0.55
        γ = snow_density(pg)
        lu, h, s = 100.0, 15.0, 10.0  # s < 20 and s < 6h=90: OK
        d = adjacent_structure_drift(pg, W2, γ, lu, h, s)
        @test d.hd <= (6 * h - s) / 6 + 1e-9
        @test d.w <= 6 * h - s + 1e-9

        @test_throws ArgumentError adjacent_structure_drift(pg, W2, γ, lu, 1.0, 20.0)
    end

    @testset "parapet_drift" begin
        pg, W2 = 30.0, 0.55
        γ = snow_density(pg)
        d = parapet_drift(pg, W2, γ, 80.0)
        @test d isa DriftLoad
        @test d.hd ≈ 0.75 * drift_height(pg, 80.0, W2, γ)
    end

    @testset "roof_projection_drift" begin
        pg, W2 = 30.0, 0.55
        γ = snow_density(pg)

        # Exception: short side.
        r = roof_projection_drift(pg, W2, γ, 40.0, 20.0, 10.0, 0.5)
        @test r.required == false
        @test r.drift === nothing

        # Exception: ample clearance.
        r2 = roof_projection_drift(pg, W2, γ, 40.0, 20.0, 20.0, 2.5)
        @test r2.required == false

        # Drift required; lu is the larger of upwind/downwind lengths.
        r3 = roof_projection_drift(pg, W2, γ, 40.0, 20.0, 20.0, 0.5)
        @test r3.required == true
        @test r3.drift.hd ≈ 0.75 * drift_height(pg, 40.0, W2, γ)
    end

end
