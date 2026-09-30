# SnowDrifts.jl

Snow **drift** magnitudes and widths per ASCE/SEI 7, Chapter 7 ("Snow
Loads"). This package computes drifts only; the regular balanced and unbalanced roof
snow loads come from the separate SnowLoads.jl. All quantities use US customary units (lb/ft², lb/ft³, ft),
consistent with the standards' worked examples. SI is not currently
supported.

## Installation

Registered in the RunToSolve Julia registry:

```julia
using Pkg
Pkg.Registry.add(url="https://github.com/runtosolve/RunToSolveJuliaRegistry")  # once
Pkg.add("SnowDrifts")
```

or directly from GitHub: `Pkg.add(url="https://github.com/runtosolve/SnowDrifts.jl")`.

No names are exported: after `using SnowDrifts`, call functions with the
module prefix, e.g. `SnowDrifts.drift_height(...)`. (You can still bring
specific names into unqualified scope with `using SnowDrifts: drift_height`
if you prefer.)

## Which design standard?

Every public function takes a `standard` keyword (a key of
`SnowDrifts.STANDARDS`, default `:ASCE7_22`):

| Key | Standard | Implemented? |
|---|---|---|
| `:ASCE7_22` | ASCE/SEI 7-22 (USA) | ✓ |
| `:ASCE7_16` | ASCE/SEI 7-16 (USA) | ✓ |
| `:ASCE7_10`, `:NBCC_2020`, `:NBCC_2015`, `:EN1991_1_3`, `:AS_NZS_1170`, `:AIJ_2015`, `:GB_50009`, `:OTHER` | — | registered, not implemented |

The unimplemented keys exist so calling code can already be written
against the full list; passing one errors with "not implemented yet"
rather than silently computing something wrong. They stay unimplemented
until someone can verify the actual drift provisions against that
standard's source text — see [Contributing another standard](#contributing-another-standard).

ASCE 7-22 and ASCE 7-16 need different site parameters, and — for drifts
at a roof step — genuinely different *mechanics*, not just different
constants in the same formula:

- **`:ASCE7_22`**: `drift_height` needs `W2` (winter wind parameter). At a
  roof step, leeward and windward drifts are checked **independently**
  (`leeward_drift`, `windward_drift`): only the leeward height is capped
  by the clear height `hc`; the windward height is not.
- **`:ASCE7_16`**: `drift_height` needs `Is` (snow importance factor,
  Table 1.5-2) instead, and uses the pre-2022 empirical relation. At a
  roof step, the **larger** of the raw leeward/windward heights is found
  first, and only *that* is capped by `hc` — both directions share one
  design drift.

Because of that difference, `leeward_drift`/`windward_drift` are
ASCE-7-22-only building blocks (they error for any other `standard`);
`roof_step_drift` is the standard-aware entry point that implements each
edition's actual mechanic and is what most calling code should use.

`W2` stays a required positional argument everywhere (for backward
compatibility); `Is` is an extra optional keyword, used only when
`standard=:ASCE7_16` (pass any placeholder for `W2` in that case — it's
ignored).

## What's implemented

| ASCE 7 reference | Function |
|---|---|
| §7.1.2 — balanced snow height | `balanced_snow_height` |
| Eq. (7.7-1) — snow density, γ | `snow_density` |
| Eq. (7.6-1) / Fig. 7.6-1 — drift height | `drift_height` |
| §7.6.1 — unbalanced surcharge, hip/gable roofs | `unbalanced_gable_hip_surcharge` |
| §7.7.1 — leeward drift on lower roof (ASCE 7-22 only) | `leeward_drift` |
| §7.7.1 — windward drift on lower roof (ASCE 7-22 only) | `windward_drift` |
| §7.7.1 — combined roof-step evaluation (both standards) | `roof_step_drift` |
| §7.7.2 — drift from adjacent structure | `adjacent_structure_drift` |
| §7.8 — parapet wall drift | `parapet_drift` |
| §7.8 — roof projection drift | `roof_projection_drift` |

`pg` (ground snow load) is site- and risk-category-specific in both
editions; `W2` (ASCE 7-22) and `Is` (ASCE 7-16) likewise. Obtain `pg`/`W2`
from the [ASCE 7 Hazard Tool](https://asce7hazardtool.online/) or, for
Alaska, Table 7.2-1 (either edition); `Is` comes from ASCE 7-16 Table
1.5-2 (0.8/1.0/1.1/1.2 for Risk Categories I–IV). This package does not
embed that geodatabase.

## Example: drift at a roof step (ASCE 7-22)

```julia
using SnowDrifts

pg, W2 = 30.0, 0.45          # from the ASCE 7 Hazard Tool
Ct = 1.0
design_code = "ASD"          # "ASD" (snow loads x 0.7) or "LRFD" (x 1.0)

# Balanced roof snow load from SnowLoads.jl (a separate package), at the same design code:
include("SnowLoads.jl")
snow = SnowLoads.compute_snow(SnowLoads.SnowInput(
    code = :ASCE7_22, method = Symbol(design_code), roof_type = :monoslope, pg = pg,
    risk_category = 2, terrain = :C, exposure = :fully, Ct = Ct, rise12 = 0.25, W = 130.0, W2 = W2))
ps = snow.factor * snow.ps          # factored balanced load

γ  = SnowDrifts.snow_density(pg)
hb = SnowDrifts.balanced_snow_height(ps, γ; design_code=design_code)

hc = 6.0            # clear height from top of balanced snow to upper roof
lu_upper = 120.0    # length of upper roof
lu_lower = 60.0     # length of lower roof

result = SnowDrifts.roof_step_drift(pg, W2, γ, hb, hc, lu_upper, lu_lower;
                                     design_code=design_code)

if result.required
    println("Governing case: ", result.governing)
    println("Leeward:  ", result.leeward)
    println("Windward: ", result.windward)
else
    println("hc/hb < 0.2 — drift loads need not be applied")
end
```

The leeward and windward drifts are separate load cases (they are not
superimposed); ASCE 7-22 §7.7.1 requires checking both independently to
determine which controls the design of a given member.

### The same roof step, under ASCE 7-16

```julia
result16 = SnowDrifts.roof_step_drift(pg, NaN, γ, hb, hc, lu_upper, lu_lower;  # W2 unused for 7-16
                                       standard=:ASCE7_16, Is=1.0, design_code=design_code)

# result16.leeward and result16.windward are the SAME DriftLoad here: ASCE 7-16
# caps whichever raw height (leeward or windward) is larger, and uses that one
# shared design drift for the roof step -- it does not track two independent
# geometries the way ASCE 7-22 does.
println("Governing case: ", result16.governing)
println("Design drift:   ", result16.leeward)
```

## Design code (ASD / LRFD)

Every function that returns a snow LOAD (the drift surcharge `pd`) takes
a required `design_code` keyword, `"ASD"` or `"LRFD"`, and returns the
load already factored: **0.7 for ASD** (§2.4.1) and **1.0 for LRFD**. Add
no snow factor of your own; only the combination factors (0.75, 1.6, 0.5,
...) remain in your load combinations. Drift heights and widths, `γ`, and
`hb` are geometric and never factored.

`pg` is the strength-level ground snow load. `balanced_snow_height` takes
the already-factored `ps` from SnowLoads.jl with the same `design_code`
and un-factors it.

## ASCE 7-22 vs. ASCE 7-16: what actually changed

ASCE 7-22 replaced the drift-height relation used since 1988,

```
hd = sqrt(Is) * (0.43 lu^(1/3) (pg + 10)^(1/4) − 1.5)      [ASCE 7-16 and earlier]
```

(which could produce negative drift heights for very short fetches —
handled with a minimum `lu` of 20 ft, and, since the 2016 edition, an
additional small-fetch cap of `sqrt(Is pg lu / 4γ)` when the actual `lu`
is below that floor) with a new relation incorporating the winter wind
parameter `W2` in place of the importance factor `Is`:

```
hd = 1.5 * sqrt( pg^0.74 * lu^0.70 * W2^1.7 / γ )          [ASCE 7-22]
```

At a roof step, ASCE 7-16 takes the larger of the raw leeward/windward
heights and caps *that single value* by the clear height `hc`. ASCE 7-22
instead checks the two independently and removed the `hc` cap from the
windward case entirely — based on field data (O'Rourke and De Angelis
2002; case histories cited in the ASCE 7-22 commentary) showing the old
shared cap underestimated windward drift loads. Both of these differences
are implemented here (see [`roof_step_drift`](#which-design-standard)
above), not just the change in the underlying `drift_height` formula.

Both editions' formulas and worked-example numbers were verified directly
against the ASCE 7-22 and ASCE 7-16 standard PDFs (Chapter 7 and its
commentary) while building this package, not from memory or secondary
sources.

## Contributing another standard

The `:ASCE7_10`, `:NBCC_2020`, `:NBCC_2015`, `:EN1991_1_3`, `:AS_NZS_1170`,
`:AIJ_2015`, and `:GB_50009` keys in `SnowDrifts.STANDARDS` are placeholders:
no verified source text for their snow-drift provisions was available
when this package was built, and the formulas were deliberately **not**
guessed from memory or web search, since an unverified structural load
formula is worse than an explicit "not implemented" error. To add real
support for one:

1. Obtain the actual standard (and commentary/worked examples, if any).
2. Implement its drift-height relation as a new branch in `drift_height`
   (`src/drift_height.jl`), following the `:ASCE7_16`/`:ASCE7_22` pattern.
3. Work out whether its roof-step mechanic is "independent" (ASCE 7-22
   style) or "coupled" (ASCE 7-16 style) or something else, and add the
   corresponding branch to `roof_step_drift`.
4. Add a test that reproduces at least one of the standard's own worked
   examples numerically (see `test/runtests.jl` for the pattern used for
   both ASCE editions).
5. Flip that standard's `implemented` flag to `true` in `STANDARDS`.

## Testing

```
julia --project=. -e 'using Pkg; Pkg.test()'
```

The test suite validates `drift_height`, `unbalanced_gable_hip_surcharge`,
and `roof_step_drift` numerically against worked examples in both the
ASCE 7-22 Commentary (§C7.6, Example 1) and the ASCE 7-16 Commentary
(§C7.6 Example 1, §C7.7 Example 3).

## Disclaimer

This package is an engineering aid, not a substitute for the standard
itself or for the judgment of a licensed professional engineer. Verify
all inputs (`pg`, `W2`/`Is`, and roof geometry) and outputs against the
governing standard before use in design.
