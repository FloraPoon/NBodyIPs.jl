
using StaticArrays

using JuLIP: AbstractCalculator,
             Atoms


import Base: Dict,
             ==

import JuLIP: cutoff,
              energy,
              forces,
              site_energies,
              virial

export NBodyIP,
       fast,
       load_ip,
       save_ip,
       energy,
       forces,
       site_energies,
       virial

# ----------- some auxiliaries we will use throughout -------------

"""
`push_str!(ex::Vector{Expr}, s::String)` : parse the string and
append it to the expressions.
"""
push_str!(ex::Vector{Expr}, s::String) = push!(ex, parse(s))


"""
`append_str!(ex::Vector{Expr}, s::Vector{String})` : parse the strings and
append them to the expressions.
"""
append_str!(ex::Vector{Expr}, s::Vector{String}) = append!(ex, parse.(s))

"""
`bo2edges(N)` : bodyorder-to-edges
"""
bo2edges(N::Integer) = (N * (N-1)) ÷ 2
bo2edges(::Val{N}) where {N} = (N * (N-1)) ÷ 2

"""
`edges2bo(M)`: "edges-to-bodyorder", an internal function that translates
the number of edges in a simplex into the body-order
"""
edges2bo(M::Integer) = (M <= 0) ? 1 : round(Int, 0.5 + sqrt(0.25 + 2 * M))

"""
`bo2angles(N)` : bodyorder-to-angles in one corner of a simplex
"""
bo2angles(N::Integer) = ((N-2) * (N-1)) ÷ 2
bo2angles(::Val{N}) where {N} = ((N-2) * (N-1)) ÷ 2

"""
`angles2bo(M)`: "angles-to-bodyorder", an internal function that translates
the number of angles in one corner of a simplex into the body-order
"""
angles2bo(A::Integer) = (M <= 0) ? 2 : round(Int, 3/2 + sqrt((9/4) + (2-2*A)))

# ----------- some generic functions that we like to have available globally
#             to overload as needed

"""
some measure of degree - could be but need not be polymomial degree; this
is basis-specific
"""
function degree end


"""
`basisid`: returns an identifier (string) specifying which basis functions
may be combined into a single function.
"""
function basisid end

"""
`combinebasis`:  if `basis::Vector{AbstractCalculator}` with identical
`basisid`, then `combinebasis(basis, coeffs)` should return a new calculator
that combines all basis function into a single IP.
"""
function combinebasis end

# prototypes for the invariants
function invariants end
function invariants_d end
function invariants_ed end

# prototypes for obtaining the descriptor
function descriptor end

function evaluate_I end
function evaluate_I_d end
function evaluate_I_ed end

bodyorder(V::NBodyFunction{N}) where {N} = N


==(V1::NBodyIP, V2::NBodyIP) = V1.components == V2.components
cutoff(V::NBodyIP) = maximum( cutoff.(V.components) )
energy(V::NBodyIP, at::Atoms) = sum( energy(Vn, at)  for Vn in V.components )
forces(V::NBodyIP, at::Atoms) = sum( forces(Vn, at)  for Vn in V.components )
virial(V::NBodyIP, at::Atoms) = sum( virial(Vn, at)  for Vn in V.components )

"""
turn a potentially slow representation of an IP into a fast one,
by switching to a different representation.
"""
fast(IP::NBodyIP) = NBodyIP( fast.(IP.components) )

function unique_components(basis)
   bods = [ (bodyorder(b), descriptor(b)) for b in basis ]
   un = Int[]
   I = Vector{Int}[]
   for i = 1:length(bods)
      found = false
      for j = 1:length(un)
         if bods[un[j]] == bods[i]
            push!(I[j], i)
            found = true
            break
         end
      end
      if !found
         push!(un, i)
         push!(I, Int[i])
      end
   end
   return I
end

# construct an NBodyIP from a basis
function NBodyIP(basis, coeffs)
   I = unique_components(basis)
   components = AbstractCalculator[ combinebasis([basis[J]...], coeffs[J])
                                    for J in I ]
   return NBodyIP(components)
end


# functionality for pure NBodyFunctions for computing
#  * site_energies
#  * energy
#  * forces
#  * virial
include("eval_nbody.jl")

# IO of NBodyIPs
include("io.jl")

# space transforms and cutoffs
include("descsupp.jl")




# ======= experimental ============

import JuLIP.Potentials: evaluate, evaluate_d

evaluate(V::NBodyFunction{2, <: BondLengthDesc}, r::AbstractFloat) =
      evaluate(V, SVector(r))
evaluate_d(V::NBodyFunction{2, <: BondLengthDesc}, r::AbstractFloat) =
      evaluate_d(V, SVector(r))[1]

evaluate(V::NBodyFunction{2, <: BondAngleDesc}, r::AbstractFloat) =
      evaluate(V, (SVector(r), SVector()))
evaluate_d(V::NBodyFunction{2, <: BondAngleDesc}, r::AbstractFloat) =
      evaluate_d(V, (SVector(r), SVector()))[1]

function evaluate(V::NBodyFunction{N}, r::SVector{M}) where {N, M}
   # this assumes that D is a BondLengthDesc
   D = descriptor(V)::BondLengthDesc
   return evaluate_I(V, invariants(D, r)) * fcut(D, r)
end

function evaluate_d(V::NBodyFunction{N}, r::SVector{M}) where {N, M}
   D = descriptor(V)::BondLengthDesc
   fc, fc_d = fcut_d(D, r)
   Vn, Vn_d = evaluate_I_ed(V, invariants_ed(D, r))
   return fc * Vn_d + fc_d * Vn
end

function evaluate(V::NBodyFunction{N}, rθ::Tuple{SVector{M1}, SVector{M2}}
                  ) where {N, M1, M2}
   # this assumes that D is a BondAngleDesc
   D = descriptor(V)::BondAngleDesc
   return evaluate_I(V, invariants(D, rθ)) * fcut(D, rθ)
end

function evaluate_d(V::NBodyFunction{N}, rθ::Tuple{SVector{M1}, SVector{M2}}
                  ) where {N, M1, M2}
   D = descriptor(V)::BondAngleDesc
   fc, fc_d = fcut_d(D, rθ)
   Vn, Vn_d = evaluate_I_ed(V, invariants_ed(D, rθ))
   return fc * Vn_d + fc_d * Vn
end
