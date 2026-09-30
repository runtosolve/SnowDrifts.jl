"""
    DriftLoad

Result of a drift-load calculation.

# Fields
- `hd::Float64`: design drift height, ft — the triangular surcharge peak
  height used for `pd`. May be capped by `hc` (leeward drifts only).
- `w::Float64`: drift width, ft — horizontal extent of the triangular
  surcharge, measured from the wall/step.
- `pd::Float64`: maximum intensity of the drift surcharge load, lb/ft²
  (`pd = factor * hd * γ`, with `factor` from `snow_load_factor(design_code)`:
  0.7 for ASD, 1.0 for LRFD). This surcharge is added on top of the balanced snow
  load `ps`, decreasing linearly to zero over the width `w`.
- `hd_raw::Float64`: the uncapped drift height directly from Eq. (7.6-1)
  (or 0.75× that value for windward/projection drifts), before any `hc`
  cap is applied. Useful for diagnostics.
"""
struct DriftLoad
    hd::Float64
    w::Float64
    pd::Float64
    hd_raw::Float64
end

function Base.show(io::IO, ::MIME"text/plain", d::DriftLoad)
    print(io, "DriftLoad(hd=$(round(d.hd, digits=3)) ft, w=$(round(d.w, digits=3)) ft, ",
          "pd=$(round(d.pd, digits=3)) psf, hd_raw=$(round(d.hd_raw, digits=3)) ft)")
end
