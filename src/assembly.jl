

using JuLIP, NeighbourLists, StaticArrays

import JuLIP.Potentials: evaluate, evaluate_d, cutoff, energy, forces
using JuLIP.Potentials: @pot

export NBody, NBodyIP


@pot struct NBody{N, T, TF, TG}
   _::Val{N}
   f::TF
   f_d::TG
   cutoff::T
end

NBody(N::Integer, f, f_d, cutoff; wrap=true) =
   NBody(Val(N), Val((N*(N-1))÷2), f, f_d, cutoff, Val(wrap))

NBody(::Val{N}, ::Val{DIM}, f, f_d, cutoff, ::Val{true}) where {N, DIM} =
   NBody(Val(N), FWrap{DIM, Float64}(f), GWrap{DIM, Float64}(f_d), Float64(cutoff))

NBody(::Val{N}, ::Val{DIM}, f, f_d, cutoff, ::Val{false}) where {N, DIM} =
   NBody(Val(N), f, f_d, cutoff)


cutoff(V::NBody) = V.cutoff

function evaluate(V::NBody{N}, at::Atoms{T}) where {N, T}
   temp = zeros(T, length(at))
   nlist = neighbourlist(at, cutoff(V))::PairList
   maptosites!(V.f, temp, nbodies(N, nlist))
   return sum_kbn(temp)
end

function evaluate_d(V::NBody{N}, at::Atoms{T}) where {N, T}
   temp = zeros(JVec{T}, length(at))
   nlist = neighbourlist(at, cutoff(V))::PairList
   return maptosites_d!(V.f_d, temp, nbodies(N, nlist))
end



struct NBodyIP <: AbstractCalculator
   orders::Vector{NBody}
end

NBodyIP(args...) = NBodyIP( [args...] )
cutoff(V::NBodyIP) = maximum( cutoff.(V.orders) )
energy(V::NBodyIP, at::Atoms) = sum( Vn(at)  for Vn in V.orders )
forces(V::NBodyIP, at::Atoms) = - sum( (@D Vn(at))  for Vn in V.orders )