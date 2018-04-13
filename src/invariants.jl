
module Invariants

using JuLIP, NeighbourLists, StaticArrays, ForwardDiff

import Base: length
import JuLIP: cutoff, energy, forces
import JuLIP.Potentials: evaluate, evaluate_d

export NBody, NBodyIP, PolyInvariants, InvInvariants, Dictionary

# ==================================================================
#           INVARIANTS
# ==================================================================


"""
`invariants(r::SVector{M,T})` : computes the invariant descriptors as a function of the
lengths in a simplex. The order is lexicographical, i.e.,

* 2-body: `r::SVector{1}`
* 3-body: `r::SVector{3}`, order is irrelevant, but `r = [r12, r13, r23]`
* 4-body: `r::SVector{6}`, order is `r = [r12, r13, r14, r23, r24, r34]`
* 5-body: `r::SVector{10}`, analogous
"""
function invariants end


"""
Use polynomials in r as the invariants
"""
struct PolyInvariants
end

invariants(::PolyInvariants, r::SVector{3, T}) where {T} = SVector{3, T}(
   r[1]+r[2]+r[3],
   r[1]*r[2] + r[1]*r[3] + r[2]*r[3],
   r[1]*r[2]*r[3] )

grad_invariants(::PolyInvariants, r::SVector{3, T}) where {T} = SVector{3, SVector{3,T}}(
      SVector{3,T}(1,1,1),
      SVector{3,T}(r[2]+r[3], r[1]+r[3], r[1]+r[2]),
      SVector{3,T}(r[2]*r[3], r[1]*r[3], r[1]*r[2])    )


"""
Use polynomials in r^{-1} as the invariants
"""
struct InvInvariants
end

invariants(::InvInvariants, r::SVector{M, T}) where {M, T} = invariants_inv(1 ./ r)
grad_invariants(::InvInvariants, r::SVector{M, T}) where {M, T} = grad_invariants_inv(1 ./ r)

invariants_inv(s::SVector{3, T}) where {T} = SVector{3, T}(
   s[1]+s[2]+s[3],
   s[1]*s[2] + s[1]*s[3] + s[2]*s[3],
   s[1]*s[2]*s[3] )

function grad_invariants_inv(s::SVector{3, T}) where {T}
   t = - s.^2
   return SVector{3, SVector{3,T}}(
      SVector{3,T}(t[1],t[2],t[3]),
      SVector{3,T}(t[1]*(s[2]+s[3]), t[2]*(s[1]+s[3]), t[3]*(s[1]+s[2])),
      SVector{3,T}(t[1]*s[2]*s[3], t[2]*s[1]*s[3], t[3]*s[1]*s[2])    )
end

# TODO
# struct ExpInvariants
# end


# ==================================================================
#           Dictionary
#
# Here we can implement a lot of generalisations, e.g.,
#  - we can change the invariants (ok, already implemented)
#  - we can implement different cutoff functions  (or put them into the invariants)
#  - allow basis functions other than polynomials of the invariants
#
# ==================================================================


@pot struct Dictionary{TINV, T}
   I::TINV                    # which invariants
   # fcut::TC                   # cut-off function
   # dfcut::TDC                 # cut-off function derivative
   # d::Vector{TF}              # dictionary functions
   # dd::Vector{TDF}            # dictionary of derivatives
   rcut::T                    # cutoff radius
end


"""
`struct Dictionary` : specifies all details about the basis functions
"""
Dictionary

@inline invariants(D::Dictionary, r) = invariants(D.I, r)
@inline grad_invariants(D::Dictionary, r) =  grad_invariants(D.I, r)

@inline fcut(D::Dictionary, r::Number) = (r - D.rcut)^2 * (r < D.rcut)
@inline fcut_d(D::Dictionary, r::Number) = 2 * (r - D.rcut) * (r < D.rcut)

@inline evaluate(D::Dictionary, i, Q) = @fastmath Q^i
@inline evaluate_d(D::Dictionary, i, Q) = (i == 0 ? 0.0 : (@fastmath i * Q^(i-1)))

cutoff(D::Dictionary) = D.rcut

fcut(D::Dictionary, r::AbstractVector) = prod(fcut(D, rr) for rr in r)

function fcut_d(D::Dictionary, r::SVector{M,T}) where {M, T}
   if maximum(r) > D.rcut-eps()
      return zero(SVector{M,T})
   end
   # now we know that they are all inside
   f = fcut(D, r)
   return (2 * f) ./ (r - D.rcut)
end

Dictionary(T::Type, rcut) = Dictionary(T(), rcut)


# ==================================================================
#           Polynomials of Invariants
# ==================================================================


@pot struct NBody{N, M, T, TI, TINV} <: AbstractCalculator
   t::Vector{NTuple{M, TI}}   # tuples
   c::Vector{T}               # coefficients
   D::Dictionary{TINV, T}
   valN::Val{N}
end

"""
`struct NBody{N, M, T <: AbstractFloat, TI <: Integer, TF}`

A struct storing the information for a pure N-body potential, i.e., containing
*only* terms of a specific body-order. Several `NBody`s can be
combined into an interatomic potential via `NBodyIP`.

### Fields

* `t::Vector{NTuple{M,TI}}` : list of M-tuples containing basis function information
e.g., if M = 3, α = t[1] is a 3-vector then this corresponds to the basis function
`f[α[1]](Q[1]) * f[α[2]](Q[2]) * f[α[3]](Q[3])` where `Q` are the 3-body invariants.

* `c`: vector of coefficients for the basis functions

* `d`: 1D function dictionary

* `rcut` : cut-off radius (all functions `f in d` must have this cutoff radius)
"""
NBody

NBody(t::Vector{NTuple{3, TI}}, c, D) where {TI} = NBody(t, c, D, Val(3))
NBody(t::Vector{NTuple{6, TI}}, c, D) where {TI} = NBody(t, c, D, Val(6))
NBody(t::Vector{NTuple{10, TI}}, c, D) where {TI} = NBody(t, c, D, Val(10))


length(V::NBody) = length(V.t)
cutoff(V::NBody) = cutoff(V.D)
bodyorder(V::NBody{N}) where {N} = N
dim(V::NBody{N,M}) where {N, M} = M

function evaluate(V::NBody{3, M, T}, r::AbstractVector{TT})  where {M, T, TT}
   # @assert length(r) == M == 3
   E = 0.0
   D = V.D
   Q = invariants(D, r)         # SVector{NI, T}
   for (α, c) in zip(V.t, V.c)
      E += c * D(α[1], Q[1]) * D(α[2], Q[2]) * D(α[3], Q[3])
   end
   fc = fcut(D, r[1]) * fcut(D, r[2]) * fcut(D, r[3])
   return E * fc
end

# evaluate_d(V::NBody{3, M, T}, r::AbstractVector{T}) where {M, T} =
#    ForwardDiff.gradient( r_ -> V(r_), r )

function evaluate_d(V::NBody{3, M, T}, r::AbstractVector{T}) where {M, T}
   E = zero(T)
   dE = zero(SVector{M, T})
   D = V.D
   Q = invariants(D, r)           # SVector{NI, T}
   dQ = grad_invariants(D, r)     # SVector{NI, SVector{M, T}}
   for (α, c) in zip(V.t, V.c)
      f1 = D(α[1], Q[1])
      f2 = D(α[2], Q[2])
      f3 = D(α[3], Q[3])
      E += c * f1 * f2 * f3
      dE += c * ((@D D(α[1], Q[1])) * f2 * f3 * dQ[1] +
                 (@D D(α[2], Q[2])) * f1 * f3 * dQ[2] +
                 (@D D(α[3], Q[3])) * f2 * f1 * dQ[3] )
   end
   fc1, fc2, fc3 = fcut(D, r[1]), fcut(D, r[2]), fcut(D, r[3])
   dfc1, dfc2, dfc3 = fcut_d(D, r[1]), fcut_d(D, r[2]), fcut_d(D, r[3])
   fc = fc1 * fc2 * fc3
   fc_d = SVector{3, Float64}(
      dfc1 * fc2 * fc3, fc1 * dfc2 * fc3, fc1 * fc2 * dfc3) 
   return dE * fc + E * fc_d
end


function energy(V::NBody{3, M, T}, at::Atoms{T}) where {M, T}
   nlist = neighbourlist(at, cutoff(V))
   Es = maptosites!(r -> V(r), zeros(length(at)), nbodies(3, nlist))
   return sum_kbn(Es)
end

function forces(V::NBody{3, M, T}, at::Atoms{T}) where {M, T}
   nlist = neighbourlist(at, cutoff(V))
   return scale!(maptosites_d!(r -> (@D V(r)),
                               zeros(SVector{3, T}, length(at)),
                               nbodies(3, nlist)), -1)
end

# ==================================================================
#           The Final Interatomic Potential
# ==================================================================


"""
`NBodyIP` : wraps `NBody`s into a JuLIP calculator, defining
`energy`, `forces` and `cutoff`.
"""
struct NBodyIP <: AbstractCalculator
   orders::Vector{NBody}
end

cutoff(V::NBodyIP) = maximum( cutoff.(V.orders) )
energy(V::NBodyIP, at::Atoms) = sum( energy(Vn, at)  for Vn in V.orders )
forces(V::NBodyIP, at::Atoms) = sum( forces(Vn, at)  for Vn in V.orders )

function NBodyIP(basis, coeffs, D::Dictionary)
   orders = NBodies[]
   bos = bodyorder.(basis)
   for N = 2:maximum(bos)
      Ibo = find(bos .== N)  # find all basis functions that have the right bodyorder
      V_N =  NBody(basis[Ibo], coeffs[Ibo], D, Val(N))
      push!(orders, V_N)  # collect them
   end
   return NBodyIP(orders)
end


end
