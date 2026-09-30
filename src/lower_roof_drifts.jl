"""
    requires_drift_load(hc, hb; standard=:ASCE7_22) -> Bool

Drift loads not required if `hc/hb < 0.2` (§7.7.1, same in both standards).
"""
function requires_drift_load(hc::Real, hb::Real; standard::Symbol=:ASCE7_22)
    check_standard(standard)
    return (hc / hb) >= 0.2
end

"""
    leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=Inf, roof_width=Inf,
                    design_code, standard=:ASCE7_22) -> DriftLoad

Leeward drift on a lower roof, **ASCE 7-22 §7.7.1 only** (errors otherwise —
use [`roof_step_drift`](@ref), since ASCE 7-16 couples leeward/windward and
can't be split into independent calls). `lu` = upper roof length.

`hd_raw = min(drift_height(pg, lu, γ; W2), 0.6*lower_roof_length)`; capped
by `hc` with the `4hd` / `4hd²/hc` width switch. `design_code` ("ASD"/"LRFD")
is required; see [`snow_load_factor`](@ref).
"""
function leeward_drift(pg::Real, W2::Real, γ::Real, lu::Real, hc::Real;
                        lower_roof_length::Real=Inf, roof_width::Real=Inf,
                        design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22)
    check_standard(standard)
    standard === :ASCE7_22 ||
        throw(ArgumentError("leeward_drift is ASCE 7-22 only; use roof_step_drift for standard=:$standard"))
    hc > 0 || throw(ArgumentError("hc must be positive"))
    hd_raw = min(drift_height(pg, lu, γ; standard=standard, W2=W2), 0.6 * lower_roof_length)
    if hd_raw <= hc
        hd = hd_raw
        w = 4 * hd
    else
        hd = hc
        w = min(4 * hd_raw^2 / hc, 8 * hc)
    end
    w = min(w, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    windward_drift(pg, W2, γ, lu; roof_width=Inf, design_code, standard=:ASCE7_22) -> DriftLoad

Windward drift on a lower roof, **ASCE 7-22 §7.7.1 only** (errors otherwise
— see [`leeward_drift`](@ref)). `lu` = lower roof length.

`hd = 0.75*drift_height(...)`, **not** capped by `hc` (a deliberate ASCE
7-22 change from 7-16); `w = 8hd`.
"""
function windward_drift(pg::Real, W2::Real, γ::Real, lu::Real; roof_width::Real=Inf,
                         design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22)
    check_standard(standard)
    standard === :ASCE7_22 ||
        throw(ArgumentError("windward_drift is ASCE 7-22 only; use roof_step_drift for standard=:$standard"))
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    roof_step_drift(pg, W2, γ, hb, hc, lu_upper, lu_lower;
                     lower_roof_length=Inf, roof_width=Inf, design_code,
                     standard=:ASCE7_22, Is=nothing)

Full §7.7.1 roof-step evaluation; the standard-aware entry point (unlike
[`leeward_drift`](@ref)/[`windward_drift`](@ref), works for both
implemented standards). `W2` is required (ASCE 7-22) even when
`standard=:ASCE7_16` is used (pass `Is` too, in that case); it is simply
ignored for 7-16.

- **`:ASCE7_22`**: leeward and windward checked independently (only
  leeward capped by `hc`); returned `leeward`/`windward` generally differ.
- **`:ASCE7_16`**: the larger of the raw leeward/windward heights is found
  first, and only *that* is capped by `hc` — one shared design drift, so
  the returned `leeward` and `windward` are the **same** `DriftLoad`.

Returns `(required, leeward, windward, governing)`.
"""
function roof_step_drift(pg::Real, W2::Real, γ::Real, hb::Real, hc::Real,
                          lu_upper::Real, lu_lower::Real;
                          lower_roof_length::Real=Inf, roof_width::Real=Inf,
                          design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                          Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    required = requires_drift_load(hc, hb; standard=standard)
    factor = snow_load_factor(design_code; standard=standard)

    if standard === :ASCE7_22
        lw = leeward_drift(pg, W2, γ, lu_upper, hc;
                            lower_roof_length=lower_roof_length, roof_width=roof_width,
                            design_code=design_code, standard=standard)
        ww = windward_drift(pg, W2, γ, lu_lower; roof_width=roof_width,
                             design_code=design_code, standard=standard)
        governing = ww.hd > lw.hd ? :windward : :leeward
        return (required=required, leeward=lw, windward=ww, governing=governing)

    elseif standard === :ASCE7_16
        hd_leeward_raw = min(drift_height(pg, lu_upper, γ; standard=standard, Is=Is),
                              0.6 * lower_roof_length)
        hd_windward_raw = 0.75 * drift_height(pg, lu_lower, γ; standard=standard, Is=Is)
        hd_gov_raw = max(hd_leeward_raw, hd_windward_raw)
        governing = hd_windward_raw > hd_leeward_raw ? :windward : :leeward
        if hd_gov_raw <= hc
            hd = hd_gov_raw
            w = 4 * hd
        else
            hd = hc
            w = min(4 * hd_gov_raw^2 / hc, 8 * hc)
        end
        w = min(w, roof_width)
        drift = DriftLoad(hd, w, factor * hd * γ, hd_gov_raw)
        return (required=required, leeward=drift, windward=drift, governing=governing)

    else
        error("internal error: standard :$standard passed check_standard but roof_step_drift " *
              "has no implementation for it")
    end
end

"""
    adjacent_structure_drift(pg, W2, γ, lu, h, s; roof_width=Inf, design_code,
                              standard=:ASCE7_22, Is=nothing)

Drift from a separate adjacent structure, §7.7.2 (same in both standards).
Applies when `s < 20 ft` and `s < 6h`. Leeward-style only: height is the
smaller of `drift_height(...)` and `(6h-s)/6`; width is the smaller of
`6*drift_height(...)` and `6h-s` (no `hc` cap here). The standard gives no
formula for the windward case beyond "use §7.7.1, truncation permitted" —
left to engineering judgment.
"""
function adjacent_structure_drift(pg::Real, W2::Real, γ::Real, lu::Real, h::Real, s::Real;
                                   roof_width::Real=Inf,
                                   design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                   Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    (s < 20 && s < 6 * h) ||
        throw(ArgumentError("§7.7.2 applies only when s < 20 ft and s < 6h"))
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2, Is=Is)
    hd = min(hd_raw, (6 * h - s) / 6)
    w = min(6 * hd_raw, 6 * h - s, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end
