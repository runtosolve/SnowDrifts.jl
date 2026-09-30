"""
    drift_height(pg, lu, γ; standard=:ASCE7_22, W2=nothing, Is=nothing) -> hd

Snow drift height, `hd` (ft). The fundamental drift-height relation used
throughout Chapter 7: unbalanced loads on hip/gable roofs (§7.6.1), drifts
on lower roofs (§7.7), and drifts at roof projections/parapets (§7.8).

Which formula is used, and which site-specific keyword it requires,
depends on `standard` (a key of [`STANDARDS`](@ref)):

- `:ASCE7_22` — Eq. (7.6-1); requires `W2`, the winter wind parameter
  (fraction of time, October–April, that wind speed is ≥ 10 mph), from
  the ASCE 7 Hazard Tool (or Table 7.2-1 for Alaska):

      hd = 1.5 * sqrt( pg^0.74 * lu^0.70 * W2^1.7 / γ )

- `:ASCE7_16` — the Fig. 7.6-1 relation; requires `Is`, the snow
  importance factor (Table 1.5-2: 0.8/1.0/1.1/1.2 for Risk Categories
  I–IV):

      hd = sqrt(Is) * (0.43 * lu_eff^(1/3) * (pg + 10)^(1/4) - 1.5)

  where `lu_eff = max(lu, 20)` ft. If the actual `lu < 20 ft`, the result
  is additionally capped at `sqrt(Is * pg * lu / (4γ))` (using the actual,
  unfloored `lu`), per the note under Fig. 7.6-1. With the mandatory
  `lu >= 20 ft` floor applied, the bracket stays positive for any
  `pg > 0`, so this doesn't happen in practice through this function —
  but the result is defensively clamped at 0 regardless, since without
  that floor (e.g. in even older, pre-2016 editions not implemented here)
  this relation could go negative for small `lu`/`pg`, which is the
  defect ASCE 7-22's `W2`-based relation was introduced to fix.

# Arguments
- `pg`: ground snow load, lb/ft²
- `lu`: length of the roof upwind of the drift, ft
- `γ`: snow density, lb/ft³, from [`snow_density`](@ref) (Eq. 7.7-1)
- `standard`: design standard (default `:ASCE7_22`; see [`STANDARDS`](@ref))
- `W2`: required when `standard === :ASCE7_22`; ignored otherwise
- `Is`: required when `standard === :ASCE7_16`; ignored otherwise
"""
function drift_height(pg::Real, lu::Real, γ::Real; standard::Symbol=:ASCE7_22,
                       W2::Union{Real,Nothing}=nothing, Is::Union{Real,Nothing}=nothing)
    check_standard(standard)
    pg > 0 || throw(ArgumentError("pg must be positive"))
    lu >= 0 || throw(ArgumentError("lu must be nonnegative"))
    γ > 0 || throw(ArgumentError("γ must be positive"))

    if standard === :ASCE7_22
        W2 === nothing &&
            throw(ArgumentError("standard=:ASCE7_22 requires the `W2` keyword (winter wind parameter)"))
        W2 > 0 || throw(ArgumentError("W2 must be positive"))
        return 1.5 * sqrt(pg^0.74 * lu^0.70 * W2^1.7 / γ)

    elseif standard === :ASCE7_16
        Is === nothing &&
            throw(ArgumentError("standard=:ASCE7_16 requires the `Is` keyword (snow importance factor, Table 1.5-2)"))
        Is > 0 || throw(ArgumentError("Is must be positive"))
        lu_eff = max(lu, 20.0)
        hd = sqrt(Is) * (0.43 * lu_eff^(1 / 3) * (pg + 10)^(1 / 4) - 1.5)
        if lu < 20
            hd = min(hd, sqrt(Is * pg * lu / (4γ)))
        end
        return max(hd, 0.0)

    else
        error("internal error: standard :$standard passed check_standard but drift_height " *
              "has no implementation for it")
    end
end
