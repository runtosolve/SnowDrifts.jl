"""
    snow_density(pg) -> γ

Snow density, γ (lb/ft³), from ASCE 7-22 Eq. (7.7-1):

    γ = 0.13 pg + 14, not more than 30 lb/ft³

`pg` is the ground snow load in lb/ft². This density is also used to
determine the balanced snow height `hb` (dividing `ps` by `γ`) and the
drift height `hd` (Eq. 7.6-1).
"""
function snow_density(pg::Real)
    pg > 0 || throw(ArgumentError("pg must be positive"))
    return min(0.13 * pg + 14, 30.0)
end

"""
    flat_roof_snow_load(pg; Ce=1.0, Ct=1.0) -> pf

Flat roof snow load, `pf` (lb/ft²), from ASCE 7-22 Eq. (7.3-1):

    pf = 0.7 Ce Ct pg

`Ce` is the exposure factor (Table 7.3-1) and `Ct` is the thermal factor
(Tables 7.3-2/7.3-3). `pg` is risk-category-specific ground snow load
(ASCE 7-22 folds the former importance factor, Is, into `pg` itself).
"""
function flat_roof_snow_load(pg::Real; Ce::Real=1.0, Ct::Real=1.0)
    pg > 0 || throw(ArgumentError("pg must be positive"))
    return 0.7 * Ce * Ct * pg
end

"""
    sloped_roof_snow_load(pf, Cs) -> ps

Sloped (balanced) roof snow load, `ps` (lb/ft²), from ASCE 7-22 Eq. (7.4-1):

    ps = Cs * pf

`Cs` is the roof slope factor determined from Figure 7.4-1.
"""
sloped_roof_snow_load(pf::Real, Cs::Real) = Cs * pf

"""
    balanced_snow_height(ps, γ) -> hb

Height of balanced snow load, `hb` (ft), per ASCE 7-22 §7.1.2:

    hb = ps / γ
"""
function balanced_snow_height(ps::Real, γ::Real)
    γ > 0 || throw(ArgumentError("γ must be positive"))
    return ps / γ
end

"""
    minimum_snow_load(pg, risk_category::Symbol) -> pm

Minimum roof snow load, `pm` (lb/ft²), for low-slope roofs per ASCE 7-22
§7.3.3 / Table 7.3-4. `risk_category` is one of `:I`, `:II`, `:III`, `:IV`.

    pm = pg,          if pg ≤ pm,max
    pm = pm,max,      otherwise
"""
function minimum_snow_load(pg::Real, risk_category::Symbol)
    pm_max = Dict(:I => 25.0, :II => 30.0, :III => 35.0, :IV => 40.0)
    haskey(pm_max, risk_category) ||
        throw(ArgumentError("risk_category must be :I, :II, :III, or :IV"))
    return min(pg, pm_max[risk_category])
end
