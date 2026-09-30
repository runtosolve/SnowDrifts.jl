"""
    unbalanced_gable_hip_surcharge(pg, γ, W, S; design_code, standard=:ASCE7_22,
                                    W2=nothing, Is=nothing) -> DriftLoad

Unbalanced (leeward) surcharge for hip and gable roofs, §7.6.1
(identically worded in ASCE 7-22 and ASCE 7-16), for roofs with
eave-to-ridge distance `W` greater than 20 ft (roofs with `W <= 20 ft`
and simply supported ridge-to-eave framing instead carry a full uniform
`pg` [`Is * pg` for ASCE 7-16] on the leeward side with the windward side
unloaded — see §7.6.1 — and are not modeled by this function).

Not applicable where the roof slope exceeds 7 on 12 (30.2°) or is less
than 1/2 on 12 (2.38°); §7.6.1 does not require unbalanced loads there.

# Arguments
- `pg`, `γ`: as in [`drift_height`](@ref)
- `W`: horizontal eave-to-ridge distance, ft (used as `lu` in [`drift_height`](@ref))
- `S`: roof slope run for a rise of one (e.g., a 6-on-12 roof has `S = 2.0`)

# Returns
A [`DriftLoad`](@ref) whose `pd` is the surcharge magnitude
`hd γ / sqrt(S)` (added to `0.3 ps` windward / `ps` leeward — see
Fig. 7.6-2) and whose `w` is the horizontal extent from the ridge,
`(8/3) hd sqrt(S)`.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default. `W2` is
required for `:ASCE7_22`, `Is` for `:ASCE7_16` (see [`drift_height`](@ref)).
"""
function unbalanced_gable_hip_surcharge(pg::Real, γ::Real, W::Real, S::Real;
                                         design_code::Union{AbstractString,Symbol}, standard::Symbol=:ASCE7_22,
                                         W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    hd = drift_height(pg, W, γ; standard=standard, W2=W2, Is=Is)
    pd = snow_load_factor(design_code; standard=standard) * hd * γ / sqrt(S)
    w = (8 / 3) * hd * sqrt(S)
    return DriftLoad(hd, w, pd, hd)
end
