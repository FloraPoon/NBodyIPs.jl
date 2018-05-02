using StaticArrays, BenchmarkTools
using DynamicPolynomials: @polyvar
import StaticPolynomials, XGrad




function fba(x)
   x2 = (x[1]*x[1], x[2]*x[2], x[3]*x[3], x[4]*x[4], x[5]*x[5],
         x[6]*x[6], x[7]*x[7], x[8]*x[8], x[9]*x[9], x[10]*x[10])
   x3 = (x2[1]*x[1], x2[2]*x[2], x2[3]*x[3], x2[4]*x[4], x2[5]*x[5],
         x2[6]*x[6], x2[7]*x[7], x2[8]*x[8], x2[9]*x[9], x2[10]*x[10])
   x4 = (x3[1]*x[1], x3[2]*x[2], x3[3]*x[3], x3[4]*x[4], x3[5]*x[5],
         x3[6]*x[6], x3[7]*x[7], x3[8]*x[8], x3[9]*x[9], x3[10]*x[10])
   x5 = (x4[1]*x[1], x4[2]*x[2], x4[3]*x[3], x4[4]*x[4], x4[5]*x[5],
         x4[6]*x[6], x4[7]*x[7], x4[8]*x[8], x4[9]*x[9], x4[10]*x[10])

   I1 = x[1] + x[2] + x[3] + x[4]

   I2 = x[5] + x[6] + x[7] + x[8] + x[9] + x[10]

   I3 = x2[1] + x2[2] + x2[3] + x2[4]

   I4 = ( x[1]*(x[5]+x[6]+x[7]) + x[2]*(x[5]+x[8]+x[9]) +
          x[3]*(x[6]+x[8]+x[10]) + x[4]*(x[7]+x[9]+x[10]) )

   I5 = x2[5] + x2[6] + x2[7] + x2[8] + x2[9] + x2[10]

   I6 = ( x[5]*(x[6]+x[7]+x[8]+x[9]) + x[6]*(x[7]+x[8]+x[10]) +
          (x[7]+x[8])*(x[9]+x[10]) + x[9]*x[10] )

   I7 = x3[1] + x3[2] + x3[3] + x3[4]

   I8 = ((x2[1]*x[5] + x2[1]*x[6] + x2[1]*x[7] + x2[2]*x[5] + x2[2]*x[8] + x2[2]*x[9]) +
      (x2[3]*x[6] + x2[3]*x[8] + x2[3]*x[10] + x2[4]*x[7] + x2[4]*x[9] + x2[4]*x[10]))

   I9 = (x[1]*x[2]*x[5] + x[1]*x[3]*x[6] + x[1]*x[4]*x[7] +
         x[2]*x[3]*x[8] + x[2]*x[4]*x[9] + x[3]*x[4]*x[10])

   I10 = ( x[1]*(x2[5]+x2[6]+x2[7]) + x[2]*(x2[5]+x2[8]+x2[9]) +
           x[3]*(x2[6]+x2[8]+x2[10]) + x[4]*(x2[7]+x2[9]+x2[10]) )

   I11 = ( x[1]*(x[5]*(x[6]+x[7]) + x[6]*x[7]) +
           x[2]*(x[5]*(x[8]+x[9]) + x[8]*x[9]) +
           x[3]*(x[6]*(x[8]+x[10]) + x[8]*x[10]) +
           x[4]*(x[7]*(x[9]+x[10]) + x[9]*x[10]) )

   I12 = x3[5] + x3[6] + x3[7] + x3[8] + x3[9] + x3[10]

   I13 = ( (x2[5]+x2[10]) * (x[6] + x[7] + x[8] + x[9]) +
           (x2[7]+x2[8] ) * (x[5] + x[6] + x[9] + x[10]) +
           (x2[6]+x2[9] ) * (x[5] + x[7] + x[8] + x[10]) )

   I14 = x[5]*(x[6]*x[7] + x[8]*x[9]) + (x[6]*x[8] + x[7]*x[9])*x[10]

   # I15 = x4[1] + x4[2] + x4[3] + x4[4]
   #
   # I16 = x3[1] * (x[5]+x[6]+x[7])   + x3[2] * (x[5]+x[8]+x[9]) +
   #       x3[3] * (x[6]+x3[8]+x[10]) + x3[4] * (x[7]+x[9]+x[10])
   #
   # I17 = ((x2[1]*x2[5] + x2[1]*x2[6] + x2[1]*x2[7] + x2[2]*x2[5] + x2[2]*x2[8] + x2[2]*x2[9]) +
   #    (x2[3]*x2[6] + x2[3]*x2[8] + x2[3]*x2[10] + x2[4]*x2[7] + x2[4]*x2[9] + x2[4]*x2[10]))
   #
   # I18 = ((x2[1]*x[5]*x[6] + x2[1]*x[5]*x[7] + x2[1]*x[6]*x[7] + x2[2]*x[5]*x[8] + x2[2]*x[5]*x[9] + x2[2]*x[8]*x[9]) +
   #     (x2[3]*x[6]*x[8] + x2[3]*x[6]*x[10] + x2[3]*x[8]*x[10] + x2[4]*x[7]*x[9] + x2[4]*x[7]*x[10] + x2[4]*x[9]*x[10]))
   #
   # I19 = x[1]*x[2]*x2[5] + x[1]*x[3]*x2[6] + x[1]*x[4]*x2[7] + x[2]*x[3]*x2[8] + x[2]*x[4]*x2[9] + x[3]*x[4]*x2[10]
   #
   # I20 = ((x[1]*x3[5] + x[1]*x3[6] + x[1]*x3[7] + x[2]*x3[5] + x[2]*x3[8] + x[2]*x3[9]) +
   #    (x[3]*x3[6] + x[3]*x3[8] + x[3]*x3[10] + x[4]*x3[7] + x[4]*x3[9] + x[4]*x3[10]))
   #
   # I21 = ( x[1]*(x2[5]*(x[6]+x[7]) + x2[6]*(x[7]+x[5]) + x2[7]*(x[5]+x[6])) +
   #         x[2]*(x2[5]*(x[8]+x[9]) + x2[8]*(x[5]+x[9]) + x2[9]*(x[5]+x[8])) +
   #         x[3]*(x2[6]*(x[8]+x[10]) + x2[8]*(x[6]+x[10]) + x2[10]*(x[6]+x[8])) +
   #         x[4]*(x2[7]*(x[9]+x[10]) + x2[9]*(x[7]+x[10]) + x2[10]*(x[7]+x[9])) )
   #
   # I22 = ( x[1]*(x2[5]*(x[8]+x[9]) + x2[6]*(x[8]+x[10]) + x2[7]*(x[9]+x[10])) +
   #         x[2]*(x2[5]*(x[6]+x[7]) + x2[8]*(x[6]+x[10]) + x2[9]*(x[7]+x[10])) +
   #         x[3]*(x2[6]*(x[5]+x[7]) + x2[8]*(x[5]+x[9]) + x2[10]*(x[7]+x[9])) +
   #         x[4]*(x2[7]*(x[5]+x[6]) + x2[9]*(x[5]+x[8]) + x2[10]*(x[6]+x[8])) )
   #
   # I23 = x4[5] + x4[6] + x4[7] + x4[8] + x4[9] + x4[10]
   #
   # I24 = ((x3[5]*x[6] + x3[5]*x[7] + x3[5]*x[8] + x3[5]*x[9] + x[5]*x3[6] + x[5]*x3[7]) +
   #    (x[5]*x3[8] + x[5]*x3[9] + x3[6]*x[7] + x3[6]*x[8] + x3[6]*x[10] + x[6]*x3[7]) +
   #    (x[6]*x3[8] + x[6]*x3[10] + x3[7]*x[9] + x3[7]*x[10] + x[7]*x3[9] + x[7]*x3[10]) +
   #    (x3[8]*x[9] + x3[8]*x[10] + x[8]*x3[9] + x[8]*x3[10] + x3[9]*x[10] + x[9]*x3[10]))
   #
   # I25 = ((x3[1]*x[2]*x[5] + x3[1]*x[3]*x[6] + x3[1]*x[4]*x[7] + x[1]*x3[2]*x[5] + x[1]*x3[3]*x[6] + x[1]*x3[4]*x[7]) +
   #    (x3[2]*x[3]*x[8] + x3[2]*x[4]*x[9] + x[2]*x3[3]*x[8] + x[2]*x3[4]*x[9] + x3[3]*x[4]*x[10] + x[3]*x3[4]*x[10]))
   #
   # I26 = ((x3[1]*x2[5] + x3[1]*x2[6] + x3[1]*x2[7] + x3[2]*x2[5] + x3[2]*x2[8] + x3[2]*x2[9]) +
   #    (x3[3]*x2[6] + x3[3]*x2[8] + x3[3]*x2[10] + x3[4]*x2[7] + x3[4]*x2[9] + x3[4]*x2[10]))
   #
   # I27 = ((x2[1]*x3[5] + x2[1]*x3[6] + x2[1]*x3[7] + x2[2]*x3[5] + x2[2]*x3[8] + x2[2]*x3[9]) +
   #    (x2[3]*x3[6] + x2[3]*x3[8] + x2[3]*x3[10] + x2[4]*x3[7] + x2[4]*x3[9] + x2[4]*x3[10]))
   #
   # I28 = ( x[1]*(x[2]*x3[5] + x[3]*x3[6] + x[4]*x3[7]) +
   #         x[2]*(x[3]*x3[8] + x[4]*x3[9]) + x[3]*x[4]*x3[10] )
   #
   # I29 = ((x[1]*x4[5] + x[1]*x4[6] + x[1]*x4[7] + x[2]*x4[5] + x[2]*x4[8] + x[2]*x4[9]) +
   #    (x[3]*x4[6] + x[3]*x4[8] + x[3]*x4[10] + x[4]*x4[7] + x[4]*x4[9] + x[4]*x4[10]))
   #
   # I30 = (x[1]*(x3[5]*(x[6] + x[7]) + x[5]*(x3[6] + x3[7]) + x3[6]*x[7] + x[6]*x3[7]) +
   #        x[2]*(x3[5]*(x[8]+x[9]) + x[5]*(x3[8]+x3[9]) + x3[8]*x[9] + x[8]*x3[9]) +
   #        x[3]*(x3[6]*(x[8]+x[10]) + x[6]*(x3[8]+x3[10]) + x3[8]*x[10] + x[8]*x3[10]) +
   #        x[4]*(x3[7]*(x[9]+x[10]) + x[7]*(x3[9]+x3[10]) + x3[9]*x[10] + x[9]*x3[10]) )
   #
   # I31 = x5[5] + x5[6] + x5[7] + x5[8] + x5[9] + x5[10]

   # return vcat(
   (I1, I2, I3, I4, I5, I6, I7, I8, I9, I10, I11, I12, I13, I14)
   #    SVector(I15, I16, I17, I18, I19, I20, I21, I22, I23, I24, I25, I26),
   #    SVector(I27, I28, I29, I30, I31)
   # )
end

r10 = @SVector rand(10)
@btime fba($r10)
ctx = Dict{Any,Any}(:nomem => true)
fba_dt = XGrad.xdiff(fba, ctx=ctx, x=tuple(r10...))
@btime fba_dt($(tuple(r10...)))



using StaticArrays, XGrad, BenchmarkTools

function fba30a(x)

   x2 = (x[1]*x[1], x[2]*x[2], x[3]*x[3], x[4]*x[4], x[5]*x[5],
         x[6]*x[6], x[7]*x[7], x[8]*x[8], x[9]*x[9], x[10]*x[10])
   x3 = (x2[1]*x[1], x2[2]*x[2], x2[3]*x[3], x2[4]*x[4], x2[5]*x[5],
         x2[6]*x[6], x2[7]*x[7], x2[8]*x[8], x2[9]*x[9], x2[10]*x[10])
   ( (x[1]*((x3[5]*(x[6] + x[7]) + x[5]*(x3[6] + x3[7])) +
                   (x3[6]*x[7] + x[6]*x3[7])) +
             x[2]*((x3[5]*(x[8]+x[9]) + x[5]*(x3[8]+x3[9])) +
                   (x3[8]*x[9] + x[8]*x3[9]))) +
            (x[3]*((x3[6]*(x[8]+x[10]) + x[6]*(x3[8]+x3[10])) +
                   (x3[8]*x[10] + x[8]*x3[10])) +
             x[4]*((x3[7]*(x[9]+x[10]) + x[7]*(x3[9]+x3[10])) +
                   (x3[9]*x[10] + x[9]*x3[10]))) )
end

fba30(x) =( (x[1]*((x[5]^3*(x[6] + x[7]) + x[5]*(x[6]^3 + x[7]^3)) +
                   (x[6]^3*x[7] + x[6]*x[7]^3)) +
             x[2]*((x[5]^3*(x[8]+x[9]) + x[5]*(x[8]^3+x[9]^3)) +
                   (x[8]^3*x[9] + x[8]*x[9]^3))) +
            (x[3]*((x[6]^3*(x[8]+x[10]) + x[6]*(x[8]^3+x[10]^3)) +
                   (x[8]^3*x[10] + x[8]*x[10]^3)) +
             x[4]*((x[7]^3*(x[9]+x[10]) + x[7]*(x[9]^3+x[10]^3)) +
                   (x[9]^3*x[10] + x[9]*x[10]^3))) )


r10 = @SVector rand(10)
fba_d = XGrad.xdiff(fba30a, ctx = Dict(:codegen => XGrad.VectorCodeGen()), x=r10)
ctx = Dict{Any,Any}(:nomem => true)
fba_dt = XGrad.xdiff(fba30a, ctx=ctx, x=tuple(r10...))
@btime fba30($r10)
@btime fba_d($r10)
@btime fba_dt($(tuple(r10...)))

using BenchmarkTools, StaticArrays
using DynamicPolynomials: @polyvar
import StaticPolynomials
@polyvar x1 x2 x3 x4 x5 x6 x7 x8 x9 x10
P_fba = StaticPolynomials.Polynomial( (x1*((x5^3*(x6 + x7) + x5*(x6^3 + x7^3)) +
                   (x6^3*x7 + x6*x7^3)) +
             x2*((x5^3*(x8+x9) + x5*(x8^3+x9^3)) +
                   (x8^3*x9 + x8*x9^3))) +
            (x3*((x6^3*(x8+x10) + x6*(x8^3+x10^3)) +
                   (x8^3*x10 + x8*x10^3)) +
             x4*((x7^3*(x9+x10) + x7*(x9^3+x10^3)) +
                   (x9^3*x10 + x9*x10^3))) )
r10 = @SVector rand(10)
@btime StaticPolynomials.evaluate($P_fba, $r10)
@btime StaticPolynomials.gradient($P_fba, $r10)




using StaticArrays, XGrad, BenchmarkTools
f(x) = ((x[1]*x[2])*x[3] + (x[1]*x[4])*x[5]) + ((x[2]*x[4])*x[6] + (x[3]*x[5])*x[6])
r = @SVector rand(6)
const ctx = Dict{Any,Any}(:nomem => true)
df = XGrad.xdiff(f, ctx=ctx, x=tuple(r...))
# df = XGrad.xdiff(f, ctx=Dict(:codegen => VectorCodeGen()), x=r)
# dft = XGrad.xdiff(f, x=tuple(r...))
@btime f($r)
@btime df($(tuple(r...)))






ctx = Dict{Any,Any}(:nomem => true)
df = XGrad.xdiff(f, ctx=ctx, x=tuple(r...))
@btime df($(tuple(r...)))

ex = :( (x[1]*((x[5]^3*(x[6] + x[7]) + x[5]*(x[6]^3 + x[7]^3)) + (x[6]^3*x[7] + x[6]*x[7]^3)) +
       x[2]*((x[5]^3*(x[8]+x[9]) + x[5]*(x[8]^3+x[9]^3)) + (x[8]^3*x[9] + x[8]*x[9]^3))) +
       (x[3]*((x[6]^3*(x[8]+x[10]) + x[6]*(x[8]^3+x[10]^3)) + (x[8]^3*x[10] + x[8]*x[10]^3)) +
       x[4]*((x[7]^3*(x[9]+x[10]) + x[7]*(x[9]^3+x[10]^3)) + (x[9]^3*x[10] + x[9]*x[10]^3))) )
ex_d = XGrad.xdiff(ex, x=tuple(r10...))

function ff(x)
   x1 = x[1]
   x2 = x[2]
   x3 = x[3]
   x4 = x[4]
   x5 = x[5]
   x6 = x[6]
   ((x1*x2)*x3 + (x1*x4)*x5) + ((x2*x4)*x6 + (x3*x5)*x6)
end
dff = XGrad.xdiff(ff, x=tuple(r...))
@btime dff($(tuple(r...)))

ex2 = quote
   x1 = x[1]
   x2 = x[2]
   x3 = x[3]
   x4 = x[4]
   x5 = x[5]
   x6 = x[6]

   ((x1*x2)*x3 + (x1*x4)*x5) + ((x2*x4)*x6 + (x3*x5)*x6)
end

dex2 = XGrad.xdiff(ex2, x=tuple(r...))
