using JuLIP, ProgressMeter
using NBodyIPs.Data: Dat, weight, config_type
using NBodyIPs: match_dictionary

using Base.Threads

import Base: kron


export get_basis, regression, naive_sparsify,
       normalize_basis!, fiterrors, scatter_data,
       print_fiterrors,
       observations, get_lsq_system

Base.norm(F::JVecsF) = norm(norm.(F))

# components of the stress (up to symmetry)
const _IS = SVector(1,2,3,5,6,9)




function assemble_lsq_block(d, Bord, Iord, nforces,
                            w_E, w_F, w_S)
   len = length(d)
   nforces = Int(min(nforces, len))
   # ------- fill the data/observations vector -------------------
   Y = Float64[]
   # energy
   push!(Y, sqrt(w_E) * energy(d))
   # forces
   if forces(d) != nothing
      f = forces(d)
      # If = rand(1:length(f), nforces)   # random subset of forces
      # f_vec = mat(f[If])[:]             # convert it into a single long vector
      f_vec = mat(f)[:]
      append!(Y, sqrt(w_F) * f_vec)                 # put force data into rhs
   end
   # stress / virial
   if virial(d) != nothing
      S = virial(d)
      append!(Y, sqrt(w_S) * S[_IS])
   end

   # ------- fill the LSQ system, i.e. evaluate basis at data points -------
   at = Atoms(d)
   # allocate (sub-) matrix of basis functions
   Ψ = zeros(length(Y), sum(length.(Bord)))

   # energies
   i0 = 0
   for n = 1:length(Bord)
      Es = energy(Bord[n], at)
      Ψ[i0+1, Iord[n]] = sqrt(w_E) * Es
   end
   i0 += 1

   # forces
   if forces(d) != nothing
      for n = 1:length(Bord)
         Fs = forces(Bord[n], at)
         for j = 1:length(Fs)
            # fb_vec = mat(Fs[j][If])[:]
            fb_vec = sqrt(w_F) * mat(Fs[j])[:]
            Ψ[(i0+1):(i0+length(fb_vec)), Iord[n][j]] = fb_vec
         end
      end
   end
   i0 += 3 * nforces

   # stresses
   if virial(d) != nothing
      for n = 1:length(Bord)
         Ss = virial(Bord[n], at)
         for j = 1:length(Ss)
            Svec = sqrt(w_S) * Ss[j][_IS]
            Ψ[(i0+1):(i0+length(_IS)), Iord[n][j]] = Svec
         end
      end
   end

   # -------- what about the weight vector ------------
   return d.w * Ψ, d.w * Y
end


function split_basis(basis)
   # get the types of the individual basis elements
   tps = typeof.(basis)
   Iord = Vector{Int}[]
   Bord = Any[]
   for tp in unique(tps)
      # find which elements of basis have type `tp`
      I = find( tp .== tps )
      push!(Iord, I)
      push!(Bord, [ b for b in basis[I]] )
   end
   return Bord, Iord
end



# TODO: parallelise!
function assemble_lsq(basis, data; verbose=true, nforces=Inf,
                      dt = verbose ? 0.5 : Inf,
                      w_E = 200.0, w_F = 1.0, w_S = 0.3 )
   # sort basis set into body-orders, and possibly different
   # types within the same body-order (e.g. for matching!)
   Bord, Iord = split_basis(basis)

   # generate many matrix blocks, one for each piece of data
   #  ==> this should be switched to pmap, or @parallel
   if nthreads() == 1
      LSQ = @showprogress(dt, "assemble LSQ",
                  [assemble_lsq_block(d, Bord, Iord, nforces, w_E, w_F, w_S)
                   for d in data])
   else
      # error("parallel LSQ assembly not implemented")
      println("Assemble LSQ with $(nthreads()) threads")
      p = Progress(length(data))
      p_ctr = 0
      p_lock = SpinLock()
      LSQ = Vector{Any}(length(data))
      tic()
      @threads for n = 1:length(data)
         LSQ[n] = assemble_lsq_block(data[n], Bord, Iord, nforces, w_E, w_F, w_S)
         lock(p_lock)
         p_ctr += 1
         ProgressMeter.update!(p, p_ctr)
         unlock(p_lock)
      end
      toc()
   end
   # combine the local matrices into a big global matrix
   nY = sum(length(block[2]) for block in LSQ)
   Ψ = zeros(nY, length(basis))
   Y = zeros(nY)
   i0 = 0
   for id = 1:length(data)
      Ψi::Matrix{Float64}, Yi::Vector{Float64} = LSQ[id]
      rows = (i0+1):(i0+length(Yi))
      Ψ[rows, :] = Ψi
      Y[rows] = Yi
      i0 += length(Yi)
   end
   W = speye(length(Y))
   return Ψ, Y, I
end



function regression(basis, data;
                    verbose = true,
                    nforces=0, usestress=false,
                    stabstyle=:basis, cstab=1e-3,
                    weights=:I,
                    regulariser = nothing,
                    w_E = 30.0, w_F = 1.0, w_S = 0.3)

   Ψ, Y, W = assemble_lsq(basis, data;
               verbose = verbose, nforces = nforces,
               w_E = w_E, w_F = w_F, w_S = w_S)

   if any(isnan, Ψ) || any(isnan, Y)
      error("discovered NaNs - something went wrong in the assembly")
   end

   @assert stabstyle == :basis

   # compute coefficients
   verbose && println("solve $(size(Ψ)) LSQ system using QR factorisation")
   Q, R = qr(Ψ)
   @show cond(R)

   if weights == :E
      ndat = length(Y) ÷ length(data)
      w = zeros(ndat, length(data))
      E0 = minimum(energy(d) for d in data)
      for (n, d) in enumerate(data)
         w[:, n] = 1.0 / ( energy(d) / length(d) - E0 + 1.0 )^2
         W = Diagonal(w[:])
      end
   end

   if W == I && regulariser == nothing
      c = (R \ (Q' * Y)) ./ (1+cstab)
   elseif regulariser == nothing
      A = Q' * (W * Q) + cstab * eye(size(R, 1))
      b = Q' * (W * Y)
      c = R \ (A \ b)
   else
      @assert W == I
      A = (1 + cstab) * R' * R + regulariser
      b = R' * Q' * Y
      c = A \ b
   end
   # check error on training set
   z = Ψ * c - Y
   rms = sqrt(dot(W * z, z) / length(Y))
   verbose && println("naive rms error on training set: ", rms)
   return c
end

# TODO:
#  - parallelise!
#  - combine rms and mae into one function
function fiterrors(V, data; verbose=true,
                   dt = verbose ? 0.5 : Inf)
   NE = 0
   NF = 0
   rmsE = 0.0
   rmsF = 0.0
   maeE = 0.0
   maeF = 0.0
   @showprogress dt "fiterrors" for d in data
      at, E, F = Atoms(d), energy(d), forces(d)
      # energy error
      Ex = energy(V, at)
      rmsE += (Ex - E)^2 / length(at)^2
      maeE += abs(Ex-E) / length(at)
      NE += 1  # number of energies
      # force error
      Fx = forces(V, at)
      rmsF += sum( norm.(Fx - F).^2 )
      maeF += sum( norm.(Fx-F) )
      NF += 3*length(Fx)   # number of forces
   end
   return sqrt(rmsE/NE), sqrt(rmsF/NF), maeE/NE, maeF / NF
end


function print_fiterrors(errs::Tuple)
   @printf("             RMSE           ||             MAE   \n")
   @printf("      E      |       F      ||      E      |     F  \n")
   @printf(" %1.5f[eV] | %2.4f[eV/A] || %1.5f[eV] | %2.4f[eV/A] \n", errs...)
end


"""
computes the maximum force over all configurations
in `data`
"""
function max_force(b, data)
   out = 0.0
   for d in data
      f = forces(b, Atoms(d))
      out = max(out, maximum(norm.(f)))
   end
   return out
end

function normalize_basis!(B, data)
   for b in B
      @assert (length(b.c) == 1)
      maxfrc = max_force(b, data)
      if maxfrc > 0
         b.c[1] /= maxfrc
      end
      if 0 < maxfrc < 1e-8
         warn("encountered a very small maxfrc = $maxfrc")
      end
   end
   return B
end

"""
remove a fraction `p` of normalised basis functions with the smallest
normalised coefficients.

NB: this returns complete *crap*.
"""
function naive_sparsify(B, c, data, p::AbstractFloat)
   # get normalisation constants for the basis functions
   nrmB = @showprogress "sparsify" [ force_norm(b, data) for b in B ]
   # normalised contributions
   cnrm = c .* nrmB
   @show nrmB
   # get the dominant contributions
   I = sortperm(abs.(cnrm))
   @show cnrm[I]
   # get the subset of indices to keep
   deleteat!(I, 1:floor(Int,length(B)*p))
   # return the sparse basis and corresponding coefficients
   return B[I], c[I]
end



function scatter_data(IP, data)
   E_data = Float64[]
   E_fit = Float64[]
   F_data = Float64[]
   F_fit = Float64[]
   for d in data
      at = Atoms(d)
      len = length(at)
      push!(E_data, energy(d) / len)
      append!(F_data, mat(forces(d))[:])
      push!(E_fit, energy(IP, at) / len)
      append!(F_fit, mat(forces(IP, at))[:])
   end
   return E_data, E_fit, F_data, F_fit
end


# ======================== NEW LSQ SETUP ========================

"""
`mutable struct IpLsqSys`: type storing all information to perform a
LSQ fit for an interatomic potential. To assemble the LsqSys use
```
dot(data, basis)
```
"""
mutable struct LsqSys
   data::Vector{Dat}
   basis::Vector{NBodyFunction}
   Iord::Vector{Vector{Int}}
   Ψ::Matrix{Float64}
end


config_types(lsq::LsqSys) = unique(config_type.(lsq.data))

"""
Take a basis and split it into individual body-orders.
"""
function split_basis(basis::AbstractVector{NBodyFunction})
   # get the types of the individual basis elements
   tps = typeof.(basis)
   Iord = Vector{Int}[]
   Bord = Any[]
   for tp in unique(tps)
      # find which elements of basis have type `tp`
      I = find( tp .== tps )
      push!(Iord, I)
      push!(Bord, [b for b in basis[I]])
   end
   return Bord, Iord
end


kron(d::Dat, B::Vector{NBodyFunction}) = dot(d, split_basis(B)...)

# ------- fill the LSQ system, i.e. evaluate basis at data points -------
function kron(d::Dat, Bord::Vector, Iord::Vector{Vector{Int}})
   len = length(d)
   at = Atoms(d)

   # allocate (sub-) matrix of basis functions
   lenY = 1 # energy
   if (forces(d) != nothing) && len > 1
      lenY += 3*len
   end
   if virial(d) != nothing
      lenY += length(_IS)
   end
   Ψ = zeros(lenY, sum(length.(Bord)))

   # energies
   i0 = 0
   for n = 1:length(Bord)
      Es = energy(Bord[n], at)
      Ψ[i0+1, Iord[n]] = Es
   end
   i0 += 1

   # forces
   if (forces(d) != nothing) && len > 1
      for n = 1:length(Bord)
         Fs = forces(Bord[n], at)
         for j = 1:length(Fs)
            fb_vec = mat(Fs[j])[:]
            Ψ[(i0+1):(i0+length(fb_vec)), Iord[n][j]] = fb_vec
         end
      end
      i0 += 3 * len
   end

   # virial components
   if virial(d) != nothing
      for n = 1:length(Bord)
         Ss = virial(Bord[n], at)
         for j = 1:length(Ss)
            Svec = Ss[j][_IS]
            Ψ[(i0+1):(i0+length(_IS)), Iord[n][j]] = Svec
         end
      end
   end

   return Ψ
end



function kron(data::Vector{TD},  basis::Vector{TB}; verbose=true
         ) where {TD <: Dat, TB <: NBodyFunction}
   # sort basis set into body-orders, and possibly different
   # types within the same body-order (e.g. for matching!)
   Bord, Iord = split_basis(basis)

   # generate many matrix blocks, one for each piece of data
   #  ==> this should be switched to pmap, or @parallel
   if nthreads() == 1
      if verbose
         println("Assembly LSQ in serial")
         LSQ = @showprogress(1.0,
                     [ kron(d, Bord, Iord) for d in data ] )
      else
         LSQ = [ kron(d, Bord, Iord) for d in data ]
      end
   else
      # error("parallel LSQ assembly not implemented")
      if verbose
         println("Assemble LSQ with $(nthreads()) threads")
         p = Progress(length(data))
         p_ctr = 0
         p_lock = SpinLock()
      end
      LSQ = Vector{Any}(length(data))
      tic()
      @threads for n = 1:length(data)
         LSQ[n] = kron(data[n], Bord, Iord)
         if verbose
            lock(p_lock)
            p_ctr += 1
            ProgressMeter.update!(p, p_ctr)
            unlock(p_lock)
         end
      end
      verbose && toc()
   end
   # combine the local matrices into a big global matrix
   nrows = sum(size(block, 1) for block in LSQ)
   Ψ = zeros(nrows, length(basis))
   i0 = 0
   for id = 1:length(data)
      Ψi::Matrix{Float64} = LSQ[id]
      i1 = i0 + size(Ψi,1)
      Ψ[(i0+1):i1, :] = Ψi
      i0 = i1
   end

   return LsqSys(data, basis, Iord, Ψ)
end


function observations(d::Dat)
   # ------- fill the data/observations vector -------------------
   Y = Float64[]
   # energy
   push!(Y, energy(d))
   # forces
   if (forces(d) != nothing) && (length(d) > 1)
      f = forces(d)
      f_vec = mat(f)[:]
      append!(Y, f_vec)
   end
   # virial
   if virial(d) != nothing
      S = virial(d)
      append!(Y, S[_IS])
   end
   return Y
end

function observations(data::AbstractVector{Dat})
   Y = Float64[]
   for d in data
      append!(Y, observations(d))
   end
   return Y
end

observations(lsq::LsqSys) = observations(lsq.data)


# ------- Fix a JLD Bug --------------------------------------

import JLD
struct LsqSysSerializer; data; basis; Iord; Ψ; end

JLD.writeas(lsq::LsqSys) = LsqSysSerializer(lsq.data, lsq.basis, lsq.Iord, lsq.Ψ)

function JLD.readas(lsq::LsqSysSerializer)
   basis = lsq.basis
   # make sure all elements of the same basis group have the
   # same dictionary; the problem is that deserialize is called
   # on each NBody individually which will give multiple types that
   # are different for the compiler but describe the same dictionary.
   for I in lsq.Iord, i = 2:length(I)
      basis[I[i]] = match_dictionary(basis[I[i]], basis[I[1]])
   end
   return  LsqSys(lsq.data, basis, lsq.Iord, lsq.Ψ)
end

# -------------------------------------------------------

using NBodyIPs.Data: config_type

function Base.info(lsq::LsqSys)
   println(repeat("=", 60))
   println(" LsqSys Summary")
   println(repeat("-", 60))
   println("      #configs: $(length(lsq.data))")
   println("    #basisfcns: $(length(lsq.basis))")
   println("  config_types: ",
         prod(s*", " for s in config_types(lsq)))

   Bord, _ = split_basis(lsq.basis)
   println(" #basis groups: $(length(Bord))")
   println(repeat("-", 60))

   for (n, B) in enumerate(Bord)
      println("   Group $n:")
      info(B; indent = 6)
   end
   println(repeat("=", 60))
end


# ------------ Refactored LSQ Fit Code


# _haskey and _getkey are to simulate named tuples

_haskey(t::Tuple, key) = length(find(first.(t) .== key)) > 0

function _getkey(t::Tuple, key)
   i = find(first.(t) .== key)
   return length(i) > 0 ? t[i[1]][2] : nothing
end

function _getkey_val(t::Tuple, key)
   i = find(first.(t) .== key)
   return length(i) > 0 ? t[i[1]][2] : 1.0
end

# TODO: hack - fix it
_getkey_val(::Void, key) = 1.0

function analyse_weights(weights::Union{Void, Tuple})
   # default weights
   w_E = 30.0
   w_F = 1.0
   w_V = 0.3
   if weights != nothing
      _haskey(weights, :E) && (w_E = _read_key(weights, :E))
      _haskey(weights, :F) && (w_F = _read_key(weights, :F))
      _haskey(weights, :V) && (w_V = _read_key(weights, :V))
   end
   return (:E => w_E, :F => w_F, :V => w_V)
end


function analyse_include_exclude(lsq, include, exclude)
   if include != nothing && exclude != nothing
      error("only one of `include`, `exclude` may be different from `nothing`")
   end
   ctypes = config_types(lsq)
   if include != nothing
      if !issubset(include, ctypes)
         error("`include` can only contain config types that are in the dataset")
      end
      # do nothing - just keep `include` as is to return
   elseif exclude != nothing
      if !issubset(exclude, ctypes)
         error("`exclude` can only contain config types that are in the dataset")
      end
      include = setdiff(ctypes, exclude)
   else
      # both are nothing => keep all config_types
      include = ctypes
   end
   return include
end


"""
`get_lsq_system(lsq; kwargs...) -> Ψ, Y, Ibasis`

Assemble the least squares system + rhs. The `kwargs` can be used to
select a subset of the available data or basis set, and to adjust the
weights by config_type. For more complex weight adjustments, one
can directly modify the `lsq.data[n].w` coefficients.

## Keyword Arguments:

* weights: either `nothing` or a tuple of `Pair`s, i.e.,
```
weights = (:E => 100.0, :F => 1.0, :V => 0.01)
```
Here `:E` stand for energy, `:F` for forces and `:V` for virial .

* config_weights: a tuple of string, value pairs, e.g.,
```
config_weights = ("solid" => 10.0, "liquid" => 0.1)
```
this adjusts the weights on individual configurations from these categories
if no weight is provided then the weight provided with the is used.
Note in particular that `config_weights` takes precedence of Dat.w!
If a weight 0.0 is used, then those configurations are removed from the LSQ
system.

* `exclude`, `include`: arrays of strings of config_types to either
include or exclude in the fit (default: all config types are included)

* `order`: integer specifying up to which body-order to include the basis
in the fit. (default: all basis functions are included)
"""
get_lsq_system(lsq; weights=nothing, config_weights=nothing,
                    exclude=nothing, include=nothing, order = Inf) =
   _get_lsq_system(lsq, analyse_weights(weights), config_weights,
                   analyse_include_exclude(lsq, include, exclude), order)

# function barrier for get_lsq_system
function _get_lsq_system(lsq, weights, config_weights, include, order)

   Y = observations(lsq)
   W = zeros(length(Y))
   # energy, force, virial weights
   w_E, w_F, w_V = last.(weights)
   # reference energy => we assume the first basis function is 1B
   E0 = lsq.basis[1]()

   # assemble the weight vector
   idx = 0
   for d in lsq.data
      len = length(d)
      # weighting factor due to config_type
      w_cfg = _getkey_val(config_weights, config_type(d))
      # weighting factor from dataset
      w = weight(d) * w_cfg

      # keep going through all data, but set the weight to zero if this
      # one is to be excluded
      if !(config_type(d) in include)
         w = 0.0
      end

      # energy
      W[idx+1] = w * w_E
      idx += 1
      # and while we're at it, subtract E0 from Y
      Y[idx] -= E0 * len

      # forces
      if (forces(d) != nothing) && (len > 1)
         W[(idx+1):(idx+3*len)] = w * w_F
         idx += 3*len
      end
      # virial
      if virial(d) != nothing
         W[(idx+1):(idx+length(_IS))] = w * w_S
      end
   end
   # double-check we haven't made a mess :)
   @assert idx == length(W) == length(Y)

   # find the zeros and remove them => list of data points
   Idata = find(W .!= 0.0) |> sort

   # find all basis functions with the required body-order
   # (note we also remove the B1, which is assumed to be at index 1)
   Ibasis = find(1 .< bodyorder.(lsq.basis) .<= order) |> sort

   # take the appropriate slices of the data and basis
   Y = Y[Idata]
   W = W[Idata]
   Ψ = lsq.Ψ[Idata, Ibasis]

   # now rescale Y and Ψ according to W => Y_W, Ψ_W; then the two systems
   #   \| Y_W - Ψ_W c \| -> min  and (Y - Ψ*c)^T W (Y - Ψ*x) => MIN
   # are equivalent
   W .= sqrt.(W)
   Y .*= W
   scale!(W, Ψ)

   if any(isnan, Ψ) || any(isnan, Y)
      error("discovered NaNs - something went horribly wrong!")
   end

   # this should be it ...
   return Ψ, Y, Ibasis
end



"""

## Keyword Arguments:

* weights: either `nothing` or a tuple of `Pair`s, i.e.,
```
weights = (:E => 100.0, :F => 1.0, :V => 0.01)
```
Here `:E` stand for energy, `:F` for forces and `:V` for virial .

* config_weights: a tuple of string, value pairs, e.g.,
```
config_weights = ("solid" => 10.0, "liquid" => 0.1)
```
this adjusts the weights on individual configurations from these categories
if no weight is provided then the weight provided with the is used.
Note in particular that `config_weights` takes precedence of Dat.w!
If a weight 0.0 is used, then those configurations are removed from the LSQ
system.
"""
function regression!(lsq;
                     verbose = true,
                     kwargs...)
   # TODO
   #  * regulariser
   #  * stabstyle or stabiliser => think about this carefully!

   # apply all the weights, get rid of anything that isn't needed or wanted
   # in particular subtract E0 from the energies and remove B1 from the
   # basis set
   Y, Ψ, Ibasis = get_lsq_system(lsq; kwargs...)

   # QR factorisation
   verbose && println("solve $(size(Ψ)) LSQ system using QR factorisation")
   QR = qrfact(Ψ)
   verbose && @show cond(QR[:R])
   # back-substitution to get the coefficients # same as QR \ ???
   c = QR \ Y

   # check error on training set: i.e. the naive errors using the
   # weights that are provided
   if verbose
      z = Ψ * c - Y
      rel_rms = norm(z) / norm(Y)
      verbose && println("naive relative rms error on training set: ", rel_rms)
   end

   # now add the 1-body term and convert this into an IP
   # (I assume that the first basis function is the 1B function)
   @assert bodyorder(lsq.basis[1]) == 1
   return NBodyIP(lsq.basis, [1.0; c])
end


function NBodyIP(lsq::LsqSys, c::Vector, Ibasis::Vector{Int})
   if !(1 in Ibasis)
      @assert bodyorder(lsq.basis[1]) == 1
      c = [1.0; c]
      Ibasis = [1; Ibasis]
   end
   return NBodyIP(lsq.basis[Ibasis], c)
end
