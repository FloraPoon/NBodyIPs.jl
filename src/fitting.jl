
using JuLIP, ProgressMeter

export get_basis, regression

function get_basis(ord, dict, sym, rcut;
                   degree=:default, kwargs...)
   dim = (ord * (ord-1)) ÷ 2
   if degree == :default
      _, fs, dfs = psym_polys(dim, dict, sym; kwargs...)
   elseif degree == :total
      _, fs, dfs = psym_polys_tot(dim, dict, sym; kwargs...)
   else
      error("unkown degree type")
   end
   return NBody.(ord, fs, dfs, rcut)
end

function assemble_system(basis, data; verbose=true)
   A = zeros(length(data), length(basis))
   F = zeros(length(data))
   lenat = 0
   if verbose
      pm = Progress(length(data) * length(basis))
   end
   for (id, d) in enumerate(data)
      at = d[1]::Atoms{Float64, Int}
      lenat = max(lenat, length(at))
      F[id] = d[2]::Float64
      for (ib, b) in enumerate(basis)
         A[id, ib] = b(at)
         if verbose
            next!(pm)
         end
      end
   end
   return A, F, lenat
end

function regression(basis, data; verbose = true)
   println("assemble system")
   A, F, lenat = assemble_system(basis, data; verbose = verbose)
   # compute coefficients
   println("solve lsq")
   Q, R = qr(A)
   c = R \ (Q' * F)
   # check error on training set
   println("rms error on training set: ",
           norm(A * c - F) / sqrt(length(data)) / sqrt(lenat) )
   return c
end


function rms(c, basis, data; verbose = false)
   A, F, lenat = assemble_system(basis, data; verbose=verbose)
   return norm(A * c - F) / sqrt(length(data)) / sqrt(lenat)
end




function fit_nbody(basis, r0, rcut)

end