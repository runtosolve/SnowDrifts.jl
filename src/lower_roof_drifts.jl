"""
    requires_drift_load(hc, hb; standard=:ASCE7_22) -> Bool

Drift loads on a lower roof are not required to be applied if
`hc / hb < 0.2` (ASCE 7-22 §7.7.1; identically worded in ASCE 7-16
§7.7.1), where `hc` is the clear height from the top of the balanced snow
load to the closest point on the adjacent (upper) roof, and `hb` is the
balanced snow height ([`balanced_snow_height`](@ref)).
"""
function requires_drift_load(hc::Real, hb::Real; standard::Symbol=:ASCE7_22)
    check_standard(standard)
    return (hc / hb) >= 0.2
end

"""
    leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=Inf, roof_width=Inf,
                    design_code, standard=:ASCE7_22) -> DriftLoad

Leeward drift on a lower roof, **ASCE 7-22 §7.7.1 only**. Snow blows off
the *upper* roof and drifts against the step onto the lower roof.

ASCE 7-22 checks the leeward and windward drifts at a roof step
independently, with only the leeward drift capped by `hc`; ASCE 7-16
instead takes the larger of the two *raw* heights first and caps that
single value by `hc` (see [`roof_step_drift`](@ref), which implements
both). Because that mechanic cannot be split into independent
leeward/windward calls, this function raises an error for any
`standard` other than `:ASCE7_22` — use `roof_step_drift` there instead.

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `lu`: length of the **upper** roof, ft
- `hc`: clear height from the top of the balanced snow load to the closest
  point on the upper roof, ft
- `lower_roof_length`: length of the lower roof, ft. The drift height need
  not be taken larger than 60% of this length (a §7.7.1 limit). Defaults
  to `Inf` (no limit applied).
- `roof_width`: available width of the lower roof, ft, used to truncate
  the drift width if it would otherwise overhang the far edge of the
  lower roof (drift "shall taper linearly to zero at the far end").
  Defaults to `Inf`.

# Method
1. `hd_raw = min(drift_height(pg, lu, γ; standard, W2), 0.6 * lower_roof_length)`
2. If `hd_raw <= hc`: `hd = hd_raw`, `w = 4 hd`.
   Else: `hd = hc`, `w = min(4 hd_raw^2 / hc, 8 hc)`.
3. `w = min(w, roof_width)`; `pd = factor * hd * γ`.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default, so every caller states
which one it wants. It sets the snow load factor of [`snow_load_factor`](@ref) applied to
the returned snow LOAD (`pd`): 0.7 for ASD (ASCE 7-22 Sec. 2.4.1) and 1.0
for LRFD (strength level; the Sec. 2.3 combination factors -- 1.6S, 1.0S, 0.5S -- are
applied by the caller). Drift heights and widths, snow density, and `hb` are geometric and
are NOT factored.
"""
function leeward_drift(pg::Real, W2::Real, γ::Real, lu::Real, hc::Real;
                        lower_roof_length::Real=Inf, roof_width::Real=Inf,
                        design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22)
    check_standard(standard)
    standard === :ASCE7_22 ||
        throw(ArgumentError("leeward_drift implements the ASCE 7-22 independent " *
                             "leeward/windward procedure only; call roof_step_drift for " *
                             "standard=:$standard, which implements each standard's own mechanic"))
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

Windward drift on a lower roof, **ASCE 7-22 §7.7.1 only**. With wind from
the opposite direction, snow drifts off the *lower* roof itself and piles
against the upstream face of the step. Raises an error for any `standard`
other than `:ASCE7_22` — see [`leeward_drift`](@ref) for why, and use
[`roof_step_drift`](@ref) instead.

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `lu`: length of the **lower** roof, ft
- `roof_width`: available width of the lower roof, ft, used to truncate
  the drift width (see [`leeward_drift`](@ref)). Defaults to `Inf`.

# Method
`hd_raw = drift_height(pg, lu, γ; standard, W2)`; the windward drift
height is `hd = 0.75 hd_raw` and the width is `w = 8 hd = 6 hd_raw`.

Per ASCE 7-22, unlike the leeward case, the windward drift height is
**not** capped by `hc` — this is a deliberate change from ASCE 7-16, based
on field data showing the prior cap underestimated windward drift loads.
The larger of the leeward and windward drift heights governs design for
a given member (§7.7.1); check both independently.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default -- see [`leeward_drift`](@ref).
"""
function windward_drift(pg::Real, W2::Real, γ::Real, lu::Real; roof_width::Real=Inf,
                         design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22)
    check_standard(standard)
    standard === :ASCE7_22 ||
        throw(ArgumentError("windward_drift implements the ASCE 7-22 independent " *
                             "leeward/windward procedure only; call roof_step_drift for " *
                             "standard=:$standard, which implements each standard's own mechanic"))
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    roof_step_drift(pg, γ, hb, hc, lu_upper, lu_lower;
                     lower_roof_length=Inf, roof_width=Inf, design_code,
                     standard=:ASCE7_22, W2=nothing, Is=nothing)

Full §7.7.1 evaluation at a roof step, for **either** ASCE 7-22 or
ASCE 7-16 (the only two `standard`s with a real implementation — see
[`STANDARDS`](@ref)): computes the leeward drift (wind from the
upper-roof side) and the windward drift (wind from the lower-roof side),
and reports whether drift loads are required at all
(`hc / hb < 0.2`, [`requires_drift_load`](@ref)).

The two standards genuinely differ in mechanic, not just in the
underlying `drift_height` formula:

- **`:ASCE7_22`**: leeward and windward are independent load cases, each
  checked on its own ([`leeward_drift`](@ref), [`windward_drift`](@ref)).
  Only the leeward height is capped by `hc`; the windward height is not.
  The returned `leeward` and `windward` fields are generally different
  `DriftLoad`s, and `governing` (`:leeward` or `:windward`, by height) is
  informational — a designer checks both independently per member.
- **`:ASCE7_16`**: the raw leeward height (`lu = lu_upper`, capped at 60%
  of `lower_roof_length`) and the raw windward height
  (`0.75 * drift_height(...; lu = lu_lower)`) are compared, and only the
  *larger* of the two is capped by `hc` (with the same `4hd` /
  `4hd^2/hc`, `<= 8hc` width switch as the leeward case above) to produce
  a single design drift. ASCE 7-16 does not track independent leeward and
  windward geometries the way ASCE 7-22 does, so here the returned
  `leeward` and `windward` fields are the **same** `DriftLoad` (the one
  governing design); `governing` indicates which raw height (leeward or
  windward) drove it.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default. `W2` is
required for `:ASCE7_22`, `Is` for `:ASCE7_16` (see [`drift_height`](@ref)).

Returns a `NamedTuple` `(required, leeward, windward, governing)`.
"""
function roof_step_drift(pg::Real, γ::Real, hb::Real, hc::Real,
                          lu_upper::Real, lu_lower::Real;
                          lower_roof_length::Real=Inf, roof_width::Real=Inf,
                          design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                          W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    required = requires_drift_load(hc, hb; standard=standard)
    factor = snow_load_factor(design_code; standard=standard)

    if standard === :ASCE7_22
        W2 === nothing &&
            throw(ArgumentError("standard=:ASCE7_22 requires the `W2` keyword (winter wind parameter)"))
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
        pd = factor * hd * γ
        drift = DriftLoad(hd, w, pd, hd_gov_raw)
        return (required=required, leeward=drift, windward=drift, governing=governing)

    else
        error("internal error: standard :$standard passed check_standard but roof_step_drift " *
              "has no implementation for it")
    end
end

"""
    adjacent_structure_drift(pg, lu, γ, h, s; roof_width=Inf, design_code,
                              standard=:ASCE7_22, W2=nothing, Is=nothing)

Drift load on a lower structure from an adjacent (separate) higher
structure, §7.7.2 (identically worded in ASCE 7-22 and ASCE 7-16).
Applies when the horizontal separation `s` is less than 20 ft and less
than `6h` (`s < 6h`), where `h` is the vertical separation distance
between the edge of the higher roof (including any parapet) and the edge
of the lower roof (excluding any parapet).

# Arguments
- `pg`, `γ`: as in [`drift_height`](@ref)
- `lu`: length of the adjacent **higher** structure, ft
- `h`: vertical separation distance, ft
- `s`: horizontal separation distance between the two structures, ft
- `roof_width`: available width of the lower roof, ft, for truncation

The leeward-drift requirements of §7.7.1 are used, except the drift
height is the smaller of the raw `drift_height` (using `lu`; no `hc` cap
applies here since one is not defined for adjacent structures) and
`(6h − s) / 6`; the drift width is the smaller of `6 * drift_height(...)`
and `6h − s` (this collapses to `6 * hd` once `hd` itself has been capped
at `(6h-s)/6`).

Only the leeward case is implemented; the standard gives no width/height
formula for the windward case here beyond "use §7.7.1 ... permitted to
be truncated" (ASCE 7-22 §7.7.2 / ASCE 7-16 §7.7.2), which is a judgment
call left to the engineer.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default. `W2` is
required for `:ASCE7_22`, `Is` for `:ASCE7_16` (see [`drift_height`](@ref)).
"""
function adjacent_structure_drift(pg::Real, lu::Real, γ::Real, h::Real, s::Real;
                                   roof_width::Real=Inf,
                                   design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                   W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    (s < 20 && s < 6 * h) ||
        throw(ArgumentError("§7.7.2 applies only when s < 20 ft and s < 6h"))
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2, Is=Is)
    hd = min(hd_raw, (6 * h - s) / 6)
    w = min(6 * hd_raw, 6 * h - s, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end
