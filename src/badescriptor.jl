
using JuLIP: JVec
const BAI = BAInvariants

# -------------- IO -------------------


BondAngleDesc(transform::String, cutoff::Union{String, Tuple}) =
         BondAngleDesc(SpaceTransform(transform), Cutoff(cutoff))

Dict(D::BondAngleDesc) = Dict( "__id__"    =>  "BondAngleDesc",
                                "transform" =>  Dict(D.transform),
                                "cutoff"    =>  Dict(D.cutoff) )

BondAngleDesc(D::Dict) = BondAngleDesc( SpaceTransform(D["transform"]),
                                          Cutoff(D["cutoff"]) )

==(D1::BondAngleDesc, D2::BondAngleDesc) =
      ( (D1.transform == D2.transform) && (D1.cutoff == D2.cutoff) )

Base.convert(::Val{:BondAngleDesc}, D::Dict) = BondAngleDesc(D)

# ------------- Interface Code ---------------

tdegrees(::BondAngleDesc, vN::Val{N}) where {N} = BAI.tdegrees(vN)

@inline ricoords(D::BondAngleDesc, Rs, J) = lengths_and_angles(Rs, J)

@inline gradri2gradR!(desc::BondAngleDesc, dVsite, dV_drθ, Rs, J, rθ) =
   _grad_rθ2pos!(dVsite, dV_drθ, Rs, J, rθ...)

# the cut-off for the bond-angle descriptor depends only on r but not on θ
@inline fcut(D::BondAngleDesc, rθ) = fcut(D.cutoff, rθ[1])

@inline function fcut_d(D::BondAngleDesc, rθ)
   fc, fc_d = fcut_d(D.cutoff, rθ[1])
   return fc, vcat(fc_d, zero(typeof(rθ[2])))
end

@inline skip_simplex(D::BondAngleDesc, rθ) = (maximum(rθ[1]) > cutoff(D.cutoff))

@inline _rθ2x(D, r, θ) = vcat(transform.(D, r), θ)
@inline _rθ2x_d(D, r, θ::SVector{K}) where {K} =
   vcat(transform_d.(D, r), @SVector ones(K))

@inline invariants(D::BondAngleDesc, rθ) = BAI.invariants(_rθ2x(D, rθ...))

@inline function invariants_ed(D::BondAngleDesc, rθ)
   x = _rθ2x(D, rθ...)
   I1, I2, DI1, DI2 = BAI.invariants_ed(x)
   x_d = _rθ2x_d(D, rθ...)
   return I1, I2, _sdot(x_d, DI1), _sdot(x_d, DI2)
end


# -------------- Kernel Functions --------------

"""
`_bondangles(Rs::AbstractVector)`

Take collection `Rs::AbstractVector{JVec}` representing a simplex
and convert into an ordered vector of bondlengths and bondangle
```
[ r1, r2, r3], [θ12, θ13, θ23 ]
[ r1, r2, r3, r4], [θ12, θ13, θ14, θ23, θ24, θ34 ]
```
"""
@generated function lengths_and_angles(Rs, J::SVector{K}) where {K}
   # note K = N-1; eltype(Rs) == JVec{T}
   code = Expr[]
   idx = 0
   # bond lengths
   str_r = "r = @SVector [ "
   for n = 1:K
      str_r *= "norm(Rs[J[$n]]), "
   end
   push_str!(code, str_r * "]")
   # bond angles
   str_θ = "θ = @SVector [ "
   for n = 1:K-1, m = (n+1):K
      idx += 1
      str_θ *= "dot(Rs[J[$n]], Rs[J[$m]]), "
   end
   push_str!(code, str_θ * "]")
   # -----
   quote
      $(Expr(:meta, :inline))
      @inbounds $(Expr(:block, code...))
      return r, θ
   end
end

"""
convert ∇V (where ∇ is the gradient w.r.t. bond-lengths and bond-angle) into
forces, i.e., into ∇Vsite (where ∇ is the gradient w.r.t. positions)
"""
@generated function _grad_rθ2pos!(dVsite, dV_drθ, Rs, J::SVector{K, Int}, r, θ) where {K}
   # K is the number of neighbours, i.e. N = K+1 counting also the center atom
   # ------
   code = Expr[]
   idx = 0
   # the first K entries of dV, are the derivatives w.r.t. |Ri|
   for k = 1:K
      idx += 1   # idx == k of course
      push!(code, :( dVsite[J[$k]] += (dV_drθ[$idx]/r[$k]) * Rs[J[$k]] ))
   end
   # the remaining ones are dot(R_i,R_j)
   for n = 1:K-1, m = (n+1):K
      idx += 1
      # str_theta *= "dot(R[$n], R[$m]), "
      push!(code, :( dVsite[J[$n]] += dV_drθ[$idx] * Rs[J[$m]] ))
      push!(code, :( dVsite[J[$m]] += dV_drθ[$idx] * Rs[J[$n]] ))
   end
   quote
      $(Expr(:meta, :inline))
      @inbounds $(Expr(:block, code...))
      return dVsite
   end
end
