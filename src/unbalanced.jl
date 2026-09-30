"""
    unbalanced_gable_hip_surcharge(pg, W2, γ, W, S; design_code, standard=:ASCE7_22,
                                    Is=nothing) -> DriftLoad

Unbalanced (leeward) surcharge for hip/gable roofs, §7.6.1 (same in both
standards), for `W > 20 ft` (`W <= 20 ft` uses full `pg` leeward /
unloaded windward instead — not modeled here). Not applicable for slope
> 7:12 or < 1/2:12.

`pd = hd*γ/sqrt(S)`, `w = (8/3)*hd*sqrt(S)`, where `hd = drift_height(pg, W, γ; ...)`.
"""
function unbalanced_gable_hip_surcharge(pg::Real, W2::Real, γ::Real, W::Real, S::Real;
                                         design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                         Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    hd = drift_height(pg, W, γ; standard=standard, W2=W2, Is=Is)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ / sqrt(S)
    w = (8 / 3) * hd * sqrt(S)
    return DriftLoad(hd, w, pd, hd)
end
