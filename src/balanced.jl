# ---------------------------------------------------------------------------
# STANDARDS - design standards selectable by the user (same list as SnowLoads.jl)
#   key => (display name, implemented?)
# ASCE/SEI 7-22 and ASCE/SEI 7-16 are implemented; the others are registered
# but intentionally blank (no verified source text for their drift provisions
# was available when this package was built -- see README).
# ---------------------------------------------------------------------------

const STANDARDS = [
    :ASCE7_22    => ("ASCE/SEI 7-22 (USA)",                        true),
    :ASCE7_16    => ("ASCE/SEI 7-16 (USA)",                        true),
    :ASCE7_10    => ("ASCE/SEI 7-10 (USA)",                        false),
    :NBCC_2020   => ("NBC Canada 2020 (Part 4, Div. B)",           false),
    :NBCC_2015   => ("NBC Canada 2015 (Part 4, Div. B)",           false),
    :EN1991_1_3  => ("EN 1991-1-3 Eurocode 1 - Snow loads",        false),
    :AS_NZS_1170 => ("AS/NZS 1170.3 (Australia / New Zealand)",    false),
    :AIJ_2015    => ("AIJ Recommendations for Loads (Japan)",      false),
    :GB_50009    => ("GB 50009 (China)",                           false),
    :OTHER       => ("Other equivalent code",                      false),
]

"""
    standard_name(standard::Symbol) -> String

Display name of a design standard key in [`STANDARDS`](@ref).
"""
standard_name(standard::Symbol) = first(Dict(STANDARDS)[standard])

"""
    check_standard(standard::Symbol)

Throws unless `standard` is a registered key of [`STANDARDS`](@ref) that is implemented.
Every public function calls this with its `standard` keyword.
"""
function check_standard(standard::Symbol)
    haskey(Dict(STANDARDS), standard) ||
        throw(ArgumentError("unknown design standard :$standard; choose from " *
                            join((":" * String(k) for (k, _) in STANDARDS), ", ")))
    last(Dict(STANDARDS)[standard]) ||
        error("Standard $(standard_name(standard)) is not implemented yet.")
    return nothing
end

"""
    snow_load_factor(design_code; standard=:ASCE7_22) -> factor

Load factor applied to ASCE 7-22 snow loads (which are strength level) so they can be
used directly in the load combinations of the given design method. `design_code` is
`"ASD"` or `"LRFD"` (a `String` or `Symbol`):

    "ASD"  -> 0.7   (Sec. 2.4.1: D + 0.7S, D + 0.75(0.7S) + ...)
    "LRFD" -> 1.0   (strength level; combination factors such as 1.6S are applied by the caller)

`standard` is the design standard (default `:ASCE7_22`, the only one implemented -- see
[`STANDARDS`](@ref)); any other key errors with "not implemented yet".
"""
function snow_load_factor(design_code::Union{AbstractString,Symbol}; standard::Symbol=:ASCE7_22)
    check_standard(standard)
    dc = String(design_code)
    dc == "ASD" && return 0.7
    dc == "LRFD" && return 1.0
    throw(ArgumentError("design_code must be \"ASD\" or \"LRFD\"; got \"$dc\""))
end

"""
    snow_density(pg; standard=:ASCE7_22) -> γ

Snow density, γ (lb/ft³), from ASCE 7-22 Eq. (7.7-1):

    γ = 0.13 pg + 14, not more than 30 lb/ft³

`pg` is the ground snow load in lb/ft². This density is used to determine the balanced
snow height `hb` (dividing `ps` by `γ`) and the drift height `hd` (Eq. 7.6-1).

`standard` is the design standard (default `:ASCE7_22`, the only one implemented -- see
[`STANDARDS`](@ref)); any other key errors with "not implemented yet".
"""
function snow_density(pg::Real; standard::Symbol=:ASCE7_22)
    check_standard(standard)
    pg > 0 || throw(ArgumentError("pg must be positive"))
    return min(0.13 * pg + 14, 30.0)
end

"""
    balanced_snow_height(ps, γ; design_code, standard=:ASCE7_22) -> hb

Height of balanced snow load, `hb` (ft), per ASCE 7-22 §7.1.2, used to decide whether a
roof-step drift is required ([`requires_drift_load`](@ref)):

    hb = ps / γ

`ps` is the balanced (sloped-roof) snow load computed elsewhere (e.g. by SnowLoads.jl) at
the SAME `design_code`, i.e. already factored; the snow load factor is divided back out here
because `hb` is a geometric height. This package does not compute the balanced or
unbalanced roof snow loads themselves -- only the drifts.

`design_code` is `"ASD"` or `"LRFD"` -- required, no default.
`standard` is the design standard (default `:ASCE7_22`, the only one implemented -- see
[`STANDARDS`](@ref)); any other key errors with "not implemented yet".
"""
function balanced_snow_height(ps::Real, γ::Real; design_code::Union{AbstractString,Symbol},
                              standard::Symbol=:ASCE7_22)
    γ > 0 || throw(ArgumentError("γ must be positive"))
    return ps / snow_load_factor(design_code; standard=standard) / γ
end
