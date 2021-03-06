
# TODO:
# * energy and forces for ASEAtoms ????
#   -> maybe define these for AbstractAtoms, then remove the
#      conversion from ASE???
# * poly_regularise
#   that is available for all sub-modules?

__precompile__()

"""
# `NBodyIPs.jl`

Package for specifying interatomic potentials based on the
N-Body expansion (ANOVA, HDMR, ...).

See `NBodyIPFitting` for the associated fitting and testing framework.
"""
module NBodyIPs

using Reexport

include("types.jl") 

# generic types and function prototypes
include("common.jl")

# definitions for the one and only 1-body function
include("onebody.jl")

# the machinery for evaluating the invariants as fast as possible
include("fastpolys.jl")

# bond-length invariants
include("blinvariants.jl")

# bond-angle invariants
include("bainvariants.jl")

# generic and specific descriptors for BL and BA
include("descriptors.jl")
# exports BondAngleDesc and BondLengthDesc

# evaluating Polynomials of an invariant coordinate system
include("polys.jl")

# codes to generate basis functions
include("polybasis.jl")
@reexport using NBodyIPs.PolyBasis

# environment dependent potentials
include("environ.jl")
@reexport using NBodyIPs.EnvIPs

end # module
