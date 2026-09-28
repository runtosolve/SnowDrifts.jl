"""
    parapet_drift(pg, W2, γ, lu; roof_width=Inf) -> DriftLoad

Drift load at a parapet wall, ASCE 7-22 §7.8. Uses the windward-drift
method of §7.7.1 ([`windward_drift`](@ref)) with `lu` equal to the length
of roof upwind of the wall, and drift height taken as three-quarters the
drift height from Eq. (7.6-1) (i.e., `hd = 0.75 * drift_height(...)`,
uncapped by any clear height).
"""
function parapet_drift(pg::Real, W2::Real, γ::Real, lu::Real; roof_width::Real=Inf)
    return windward_drift(pg, W2, γ, lu; roof_width=roof_width)
end

"""
    roof_projection_drift(pg, W2, γ, lu_upwind, lu_downwind, side_length, clearance;
                           roof_width=Inf)

Drift load at a roof projection (e.g., a mechanical curb or penthouse),
ASCE 7-22 §7.8. Uses the windward-drift method of §7.7.1
([`windward_drift`](@ref)), applied on all sides of the projection, with
`lu` equal to the greater of the length of roof upwind or downwind of the
projection.

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `lu_upwind`, `lu_downwind`: lengths of roof upwind and downwind of the
  projection, ft — `lu = max(lu_upwind, lu_downwind)` is used
- `side_length`: length of the side of the roof projection, ft
- `clearance`: clear distance between the height of the balanced snow
  load, `hb`, and the bottom of the projection (including horizontal
  supports), ft
- `roof_width`: available width of roof for width truncation, ft

# Exception (§7.8)
Drift loads are **not required** where `side_length < 15 ft`, or where
`clearance >= 2 ft`. In that case this function returns
`(required=false, drift=nothing)`.
"""
function roof_projection_drift(pg::Real, W2::Real, γ::Real, lu_upwind::Real,
                                lu_downwind::Real, side_length::Real,
                                clearance::Real; roof_width::Real=Inf)
    if side_length < 15 || clearance >= 2
        return (required=false, drift=nothing)
    end
    lu = max(lu_upwind, lu_downwind)
    drift = windward_drift(pg, W2, γ, lu; roof_width=roof_width)
    return (required=true, drift=drift)
end
