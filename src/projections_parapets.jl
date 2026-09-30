"""
    parapet_drift(pg, γ, lu; roof_width=Inf, design_code, standard=:ASCE7_22,
                  W2=nothing, Is=nothing) -> DriftLoad

Drift load at a parapet wall, §7.8 (identically worded in ASCE 7-22 and
ASCE 7-16). Uses the windward-drift method of §7.7.1 with `lu` equal to
the length of roof upwind of the wall, and drift height taken as
three-quarters the drift height from [`drift_height`](@ref) (i.e.,
`hd = 0.75 * drift_height(...)`, uncapped by any clear height, in both
standards).

`design_code` is `"ASD"` or `"LRFD"` -- required, no default. `W2` is
required for `:ASCE7_22`, `Is` for `:ASCE7_16` (see [`drift_height`](@ref)).
"""
function parapet_drift(pg::Real, γ::Real, lu::Real; roof_width::Real=Inf,
                        design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                        W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2, Is=Is)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    roof_projection_drift(pg, γ, lu_upwind, lu_downwind, side_length, clearance;
                           roof_width=Inf, design_code, standard=:ASCE7_22,
                           W2=nothing, Is=nothing)

Drift load at a roof projection (e.g., a mechanical curb or penthouse),
§7.8 (identically worded in ASCE 7-22 and ASCE 7-16). Uses the
windward-drift method of §7.7.1, applied on all sides of the projection,
with `lu` equal to the greater of the length of roof upwind or downwind
of the projection.

# Arguments
- `pg`, `γ`: as in [`drift_height`](@ref)
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

`design_code` is `"ASD"` or `"LRFD"` -- required, no default. `W2` is
required for `:ASCE7_22`, `Is` for `:ASCE7_16` (see [`drift_height`](@ref)).
"""
function roof_projection_drift(pg::Real, γ::Real, lu_upwind::Real,
                                lu_downwind::Real, side_length::Real,
                                clearance::Real; roof_width::Real=Inf,
                                design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    if side_length < 15 || clearance >= 2
        return (required=false, drift=nothing)
    end
    lu = max(lu_upwind, lu_downwind)
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2, Is=Is)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return (required=true, drift=DriftLoad(hd, w, pd, hd_raw))
end
