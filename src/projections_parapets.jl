"""
    parapet_drift(pg, W2, γ, lu; roof_width=Inf, design_code, standard=:ASCE7_22,
                  Is=nothing) -> DriftLoad

Drift at a parapet wall, §7.8 (same in both standards). `lu` = roof length
upwind of the wall. `hd = 0.75*drift_height(...)`, uncapped by `hc`; `w = 8hd`.
"""
function parapet_drift(pg::Real, W2::Real, γ::Real, lu::Real; roof_width::Real=Inf,
                        design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                        Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    hd_raw = drift_height(pg, lu, γ; standard=standard, W2=W2, Is=Is)
    hd = 0.75 * hd_raw
    w = min(8 * hd, roof_width)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ
    return DriftLoad(hd, w, pd, hd_raw)
end

"""
    roof_projection_drift(pg, W2, γ, lu_upwind, lu_downwind, side_length, clearance;
                           roof_width=Inf, design_code, standard=:ASCE7_22, Is=nothing)

Drift at a roof projection, §7.8 (same in both standards). `lu` is the
greater of `lu_upwind`/`lu_downwind`. Exception (no drift required):
`side_length < 15 ft` or `clearance >= 2 ft` — returns `(required=false,
drift=nothing)`. Otherwise same `0.75*hd` / `8hd` method as [`parapet_drift`](@ref).
"""
function roof_projection_drift(pg::Real, W2::Real, γ::Real, lu_upwind::Real,
                                lu_downwind::Real, side_length::Real,
                                clearance::Real; roof_width::Real=Inf,
                                design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                Is::Union{Real,Nothing}=nothing)
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
