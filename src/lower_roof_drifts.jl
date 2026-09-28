"""
    requires_drift_load(hc, hb) -> Bool

ASCE 7-22 §7.7.1: drift loads on a lower roof are not required to be
applied if `hc / hb < 0.2`, where `hc` is the clear height from the top of
the balanced snow load to the closest point on the adjacent (upper) roof,
and `hb` is the balanced snow height ([`balanced_snow_height`](@ref)).
"""
requires_drift_load(hc::Real, hb::Real) = (hc / hb) >= 0.2

"""
    leeward_drift(pg, W2, γ, lu, hc; lower_roof_length=Inf, roof_width=Inf) -> DriftLoad

Leeward drift on a lower roof, ASCE 7-22 §7.7.1. Snow blows off the *upper*
roof and drifts against the step onto the lower roof.

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
1. `hd_raw = min(drift_height(pg, lu, W2, γ), 0.6 * lower_roof_length)`
2. If `hd_raw <= hc`: `hd = hd_raw`, `w = 4 hd`.
   Else: `hd = hc`, `w = min(4 hd_raw^2 / hc, 8 hc)`.
3. `w = min(w, roof_width)`; `pd = hd * γ`.
"""
function leeward_drift(pg::Real, W2::Real, γ::Real, lu::Real, hc::Real;
                        lower_roof_length::Real=Inf, roof_width::Real=Inf)
    hc > 0 || throw(ArgumentError("hc must be positive"))
    hd_raw = min(drift_height(pg, lu, W2, γ), 0.6 * lower_roof_length)
    if hd_raw <= hc
        hd = hd_raw
        w = 4 * hd
    else
        hd = hc
        w = min(4 * hd_raw^2 / hc, 8 * hc)
    end
    w = min(w, roof_width)
    pd = hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    windward_drift(pg, W2, γ, lu; roof_width=Inf) -> DriftLoad

Windward drift on a lower roof, ASCE 7-22 §7.7.1. With wind from the
opposite direction, snow drifts off the *lower* roof itself and piles
against the upstream face of the step.

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `lu`: length of the **lower** roof, ft
- `roof_width`: available width of the lower roof, ft, used to truncate
  the drift width (see [`leeward_drift`](@ref)). Defaults to `Inf`.

# Method
`hd_raw = drift_height(pg, lu, W2, γ)`; the windward drift height is
`hd = 0.75 hd_raw` and the width is `w = 8 hd = 6 hd_raw`.

Per ASCE 7-22, unlike the leeward case, the windward drift height is
**not** capped by `hc` — this is a deliberate change from ASCE 7-16, based
on field data showing the prior cap underestimated windward drift loads.
The larger of the leeward and windward drift heights governs design for
a given member (§7.7.1); check both independently.
"""
function windward_drift(pg::Real, W2::Real, γ::Real, lu::Real; roof_width::Real=Inf)
    hd_raw = drift_height(pg, lu, W2, γ)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    roof_step_drift(pg, W2, γ, hb, hc, lu_upper, lu_lower;
                     lower_roof_length=Inf, roof_width=Inf)

Full ASCE 7-22 §7.7.1 evaluation at a roof step: computes both the
leeward drift (wind from the upper-roof side) and the windward drift
(wind from the lower-roof side), and reports whether drift loads are
required at all (`hc / hb < 0.2` per [`requires_drift_load`](@ref)).

Windward and leeward drifts are separate load cases that are not
superimposed; §7.7.1 requires each to be checked independently to
determine which controls the design of a given member.

Returns a `NamedTuple` `(required, leeward, windward, governing)` where
`governing` is `:leeward` or `:windward`, whichever has the larger `hd`
(meaningful only when `required` is `true`).
"""
function roof_step_drift(pg::Real, W2::Real, γ::Real, hb::Real, hc::Real,
                          lu_upper::Real, lu_lower::Real;
                          lower_roof_length::Real=Inf, roof_width::Real=Inf)
    required = requires_drift_load(hc, hb)
    lw = leeward_drift(pg, W2, γ, lu_upper, hc;
                        lower_roof_length=lower_roof_length, roof_width=roof_width)
    ww = windward_drift(pg, W2, γ, lu_lower; roof_width=roof_width)
    governing = ww.hd > lw.hd ? :windward : :leeward
    return (required=required, leeward=lw, windward=ww, governing=governing)
end

"""
    adjacent_structure_drift(pg, W2, γ, lu, h, s; roof_width=Inf)

Drift load on a lower structure from an adjacent (separate) higher
structure, ASCE 7-22 §7.7.2. Applies when the horizontal separation `s`
is less than 20 ft and less than `6h` (`s < 6h`), where `h` is the
vertical separation distance between the edge of the higher roof
(including any parapet) and the edge of the lower roof (excluding any
parapet).

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `lu`: length of the adjacent **higher** structure, ft
- `h`: vertical separation distance, ft
- `s`: horizontal separation distance between the two structures, ft
- `roof_width`: available width of the lower roof, ft, for truncation

The leeward-drift requirements of §7.7.1 are used, except the drift
height is the smaller of the §7.7.1 leeward `hd` (using `lu`, with no
`hc` cap applied here since one is not defined for adjacent structures)
and `(6h − s) / 6`; the drift width is the smaller of `4 hd`-derived
width and `6h − s`.
"""
function adjacent_structure_drift(pg::Real, W2::Real, γ::Real, lu::Real,
                                   h::Real, s::Real; roof_width::Real=Inf)
    (s < 20 && s < 6 * h) ||
        throw(ArgumentError("§7.7.2 applies only when s < 20 ft and s < 6h"))
    hd_raw = drift_height(pg, lu, W2, γ)
    hd = min(hd_raw, (6 * h - s) / 6)
    w = min(4 * hd, 6 * hd_raw, 6 * h - s, roof_width)
    pd = hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end
