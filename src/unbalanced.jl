"""
    unbalanced_gable_hip_surcharge(pg, W2, γ, W, S) -> DriftLoad

Unbalanced (leeward) surcharge for hip and gable roofs, ASCE 7-22 §7.6.1,
for roofs with eave-to-ridge distance `W` greater than 20 ft (roofs with
`W <= 20 ft` and simply supported ridge-to-eave framing instead carry a
full uniform `pg` on the leeward side with the windward side unloaded —
see §7.6.1 — and are not modeled by this function).

Not applicable where the roof slope exceeds 7 on 12 (30.2°) or is less
than 1/2 on 12 (2.38°); §7.6.1 does not require unbalanced loads there.

# Arguments
- `pg`, `W2`, `γ`: as in [`drift_height`](@ref)
- `W`: horizontal eave-to-ridge distance, ft (used as `lu` in Eq. 7.6-1)
- `S`: roof slope run for a rise of one (e.g., a 6-on-12 roof has `S = 2.0`)

# Returns
A [`DriftLoad`](@ref) whose `pd` is the surcharge magnitude
`hd γ / sqrt(S)` (added to `0.3 ps` windward / `ps` leeward — see
Fig. 7.6-2) and whose `w` is the horizontal extent from the ridge,
`(8/3) hd sqrt(S)`.
"""
function unbalanced_gable_hip_surcharge(pg::Real, W2::Real, γ::Real, W::Real, S::Real)
    hd = drift_height(pg, W, W2, γ)
    pd = hd * γ / sqrt(S)
    w = (8 / 3) * hd * sqrt(S)
    return DriftLoad(hd, w, pd, hd)
end
