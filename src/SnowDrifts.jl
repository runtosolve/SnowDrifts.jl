"""
    SnowDrifts

Snow drift magnitudes and widths per ASCE/SEI 7 Chapter 7 ("Snow Loads").
This package computes DRIFTS ONLY. The regular balanced and unbalanced
roof snow loads (`pf`, `ps`, `pm`, gable unbalanced load, rain-on-snow)
come from a separate package (SnowLoads.jl); pass its (factored) `ps` in
as `hb = balanced_snow_height(ps, γ; design_code)` where a drift needs it.
Implements:

- Eq. (7.6-1)/Fig. 7.6-1: drift height, `hd`
- Eq. (7.7-1): snow density, `γ`
- §7.6.1: unbalanced surcharge for hip/gable roofs
- §7.7.1: leeward and windward drifts on lower roofs
- §7.7.2: drifts from adjacent structures
- §7.8: drifts at roof projections and parapets

All quantities use US customary units consistent with the standard's
worked examples: lb/ft² for pressures, lb/ft³ for density, and ft for
lengths and heights. SI is not currently supported.

## Design standard (user input)

Every public function takes `standard` (a key of [`STANDARDS`](@ref),
default `:ASCE7_22`), the same list as SnowLoads.jl:

| Key | Standard | Implemented? |
|---|---|---|
| `:ASCE7_22` | ASCE/SEI 7-22 (USA) | ✓ |
| `:ASCE7_16` | ASCE/SEI 7-16 (USA) | ✓ |
| `:ASCE7_10`, `:NBCC_2020`, `:NBCC_2015`, `:EN1991_1_3`, `:AS_NZS_1170`, `:AIJ_2015`, `:GB_50009`, `:OTHER` | — | registered, but not implemented: no verified source text for their drift provisions was available when this package was built. Passing one of these errors with "not implemented yet" rather than silently computing something wrong. Contributions welcome if you can verify against the actual standard. |

ASCE 7-22 and ASCE 7-16 use genuinely different site parameters and, for
lower-roof drifts, genuinely different mechanics — not just different
constants in the same formula:

- **`:ASCE7_22`** — [`drift_height`](@ref) needs `W2` (winter wind
  parameter). At a roof step ([`roof_step_drift`](@ref)), leeward and
  windward drifts are checked **independently**: only the leeward height
  is capped by the clear height `hc`; the windward height is not (a
  deliberate ASCE 7-22 change from 7-16 — see below).
- **`:ASCE7_16`** — `drift_height` needs `Is` (snow importance factor,
  Table 1.5-2) instead, and uses the pre-2022 empirical relation (which,
  unlike the `W2`-based Eq. 7.6-1, can go negative for small `lu`/`pg` —
  clamped at 0 here). At a roof step, the **larger** of the raw leeward
  and windward heights is found first, and *that single value* is capped
  by `hc` — both directions share one design height, unlike ASCE 7-22.

Because of that last difference, [`leeward_drift`](@ref) and
[`windward_drift`](@ref) are ASCE-7-22-only building blocks (they error
for any other `standard`); [`roof_step_drift`](@ref) is the standard-aware
entry point that implements each edition's actual mechanic and should be
preferred when more than one standard might be selected. The simpler
drift locations — [`adjacent_structure_drift`](@ref),
[`parapet_drift`](@ref), [`roof_projection_drift`](@ref),
[`unbalanced_gable_hip_surcharge`](@ref) — read identically in both
editions' text, so they dispatch on `standard` internally and accept
either `W2` or `Is` as a keyword.

Ground snow load `pg`, the winter wind parameter `W2` (ASCE 7-22), and
the snow importance factor `Is` (ASCE 7-16) are site- and
risk-category-specific; obtain `pg`/`W2` from the ASCE 7 Hazard Tool
(https://asce7hazardtool.online/) or, for Alaska, Table 7.2-1 (either
edition). This package does not embed that geodatabase.

## Design code (user input)

Every function that returns a snow LOAD (the drift surcharge `pd`) takes
a required `design_code` keyword, `"ASD"` or `"LRFD"`, and returns the
load already multiplied by [`snow_load_factor`](@ref): 0.7 for ASD
(§2.4.1), 1.0 for LRFD (strength level). Callers therefore add NO snow
factor of their own for that step; only the combination-specific factors
(0.75, 1.6, 0.5, ...) remain in the load combinations. Geometric outputs
(`γ`, `hd`, `w`, `hb`) are never factored. The input `pg` is the
strength-level ground snow load.

## Output variables

Most functions return a single `Float64`. The drift functions return a
[`DriftLoad`](@ref), with fields:

| Field | Meaning | Units |
|---|---|---|
| `hd` | design drift height (surcharge peak) | ft |
| `w` | drift width (horizontal extent of the surcharge) | ft |
| `pd` | maximum drift surcharge intensity, `pd = factor * hd * γ` (factored for `design_code`) | lb/ft² |
| `hd_raw` | drift height before any `hc` cap is applied | ft |

| Function | Returns |
|---|---|
| `snow_load_factor` | 0.7 (ASD) or 1.0 (LRFD) |
| `snow_density` | `γ`, snow density, lb/ft³ |
| `balanced_snow_height` | `hb`, height of balanced snow load, ft (geometric; un-factors the `ps` passed in) |
| `drift_height` | `hd`, drift height, ft |
| `requires_drift_load` | `Bool` — whether `hc/hb >= 0.2` |
| `leeward_drift`, `windward_drift`, `adjacent_structure_drift`, `parapet_drift` | `DriftLoad` |
| `unbalanced_gable_hip_surcharge` | `DriftLoad` (`pd` is the surcharge intensity, `w` its extent from the ridge) |
| `roof_step_drift` | `NamedTuple(required::Bool, leeward::DriftLoad, windward::DriftLoad, governing::Symbol)` — `leeward`/`windward` are the SAME `DriftLoad` for `:ASCE7_16` (see above) |
| `roof_projection_drift` | `NamedTuple(required::Bool, drift::Union{DriftLoad,Nothing})` |
"""
module SnowDrifts

include("types.jl")
include("balanced.jl")
include("drift_height.jl")
include("lower_roof_drifts.jl")
include("projections_parapets.jl")
include("unbalanced.jl")

end # module SnowDrifts
