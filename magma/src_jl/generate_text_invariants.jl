using Combinatorics, StaticArrays

include("invariants_generator.jl")
include("misc.jl")
include("inv_monomials.jl")

# Parameters
#TODO: check that prefix are the same as the ones in generate_invariants.sh
NBody = 5;
Deg = 6;
prefsec = "SEC" #prefix for the secondaries
prefirrsec = "IS" #prefix for the irreducible secondaries
prefprim = "P" #prefix for the primaries
# --------------
NBlengths = Int(NBody*(NBody-1)/2);

# -------------------------------------------
#
# Generate irreducible secondaries
#
# -------------------------------------------
filenameirrsec1 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text1.jl";
filenameirrsec2 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text2.jl";
filenameirrsec3 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text3.jl";
filenameirrsec4 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text4.jl";
filenameirrsec5 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text5.jl";
filenameirrsecdata = "magma/data/NB_$NBody""_deg_$Deg""/NB_$NBody"*"_deg_$Deg"*"_irr_invariants.jl";
preword = "# Irreducible secondaries for NBody=$NBody"*"and deg=$Deg \n"

NB_irrsec = countlines(filenameirrsecdata)

max_exp_irrsec = generate_invariants(filenameirrsecdata,filenameirrsec1,filenameirrsec2,filenameirrsec3,filenameirrsec4,filenameirrsec5,NBlengths,Deg,preword,prefirrsec)


# -------------------------------------------
#
# Generate primary invariants
#
# -------------------------------------------
filenameprim1 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text1.jl";
filenameprim2 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text2.jl";
filenameprim3 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text3.jl";
filenameprim4 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text4.jl";
filenameprim5 = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text5.jl";
filenameprimdata = "magma/data/NB_$NBody""_deg_$Deg""/NB_$NBody"*"_deg_$Deg"*"_prim_invariants.jl";
preword = "# Primary invariants for NBody=$NBody"*"and deg=$Deg \n"
NB_prim = countlines(filenameprimdata)

max_exp_prim = generate_invariants(filenameprimdata,filenameprim1,filenameprim2,filenameprim3,filenameprim4,filenameprim5,NBlengths,Deg,preword,prefprim)
# -------------------------------------------
#
# Secondary invariants (relations with irreducible secondaries)
#
# -------------------------------------------
filenamesec = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_relations_invariants.jl";
NB_secondary = countlines(filenamesec);
# -------------------------------------------
#
# Derivatives of secondary invariants (relations with irreducible secondaries)
#
# -------------------------------------------
filenamesec_d = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_relations_invariants_derivatives.jl";

open(filenamesec_d, "w") do f
end

fileI = open(filenamesec)
line = readlines(fileI)
part1,part2 = split(line[1], "=")
repl1 = replace(part1, prefsec, "d"*prefsec)
open(filenamesec_d, "a") do f
    write(f, repl1, " = @SVector zeros($NBlengths) \n")
end
for i=2:length(line)
    if contains(line[i], "*")
        part1,part2 = split(line[i], "=")
        part2_1,part2_2 = split(part2, "*")
        repl1 = replace(part1, prefsec, "d"*prefsec)
        repl2_1 = replace(part2_1, prefirrsec, "d"*prefirrsec)
        repl2_2 = replace(part2_2, prefirrsec, "d"*prefirrsec)
        open(filenamesec_d, "a") do f
            write(f, repl1, " = ", repl2_1, "*", part2_2, "+", part2_1, "*", repl2_2, "\n")
        end
    else
        open(filenamesec_d, "a") do f
            repl1 = replace(line[i], prefsec, "d"*prefsec)
            repl2 = replace(repl1, prefirrsec, "d"*prefirrsec)
            write(f, repl2, "\n")
        end
    end
end


# -------------------------------------------
#
# Generate function with all invariants
#
# -------------------------------------------
file = "magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_invariants.jl";

open(file, "w") do f
    write(f, "using StaticArrays \n")
    write(f, "using BenchmarkTools: @btime \n\n")
    # write(f, "include(\"fastpolys.jl\") \n")
    # write(f, "using FastPolys \n\n\n\n")

    # write the definition of the constant vectors
    prim1 = read(filenameprim1)
    write(f, prim1)
    irrsec1 = read(filenameirrsec1)
    write(f, irrsec1)

    # write the definitions of the types
    write(f, "\n")
    prim2 = read(filenameprim2)
    write(f, prim2)
    irrsec2 = read(filenameirrsec2)
    write(f, irrsec2)

    write(f, "\n\n")

    # write the name of the function
    write(f, "function invariants_gen(x1::SVector{$NBlengths, T}) where {T}\n")

    # write the precomputed powers of x
    for i=2:max(max_exp_irrsec,max_exp_prim)
        im = i-1;
        write(f, "   x$i = x$im.*x1 \n")
    end

    # write the primary invariants
    write(f, "   #------------------------------------------------\n")
    write(f, "   # Primaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n")
    prim3 = read(filenameprim3)
    write(f, prim3)

    # write the irreducible secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # Irreducible secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    irrsec3 = read(filenameirrsec3)
    write(f, irrsec3)

    # write all the secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # All secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    sec = read(filenamesec)
    write(f, sec)

    #write the return part
    write(f, "\n\n")
    write(f, "return (@SVector [")
    for i=1:NB_prim
        write(f, prefprim, "$i,")
    end
    write(f, "]), (@SVector [")
    for i=1:NB_secondary
        write(f, prefsec, "$i,")
    end
    write(f, "])\n end")



    # -------------------------------------------
    #
    # Generate derivatives of the invariants
    #
    # -------------------------------------------
    write(f, "\n\n\n\n")
    write(f, "function invariants_d_gen(x1::SVector{$NBlengths, T}) where {T}\n")
    for i=2:max(max_exp_irrsec,max_exp_prim)
        im = i-1;
        write(f, "   x$i = x$im.*x1 \n")
    end
    write(f, "\n   dx1 = @SVector ones($NBlengths)\n")
    for i=2:max(max_exp_irrsec,max_exp_prim)
        im = i-1;
        write(f, "   dx$i = $i * x$im \n")
    end

    # write the primary invariants
    write(f, "   #------------------------------------------------\n")
    write(f, "   # Primaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n")
    prim4 = read(filenameprim4)
    write(f, prim4)

    # write the irreducible secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # Irreducible secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    irrsec3 = read(filenameirrsec3)
    write(f, irrsec3)

    write(f, "\n\n")
    irrsec4 = read(filenameirrsec4)
    write(f, irrsec4)

    # write all the secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # All secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    sec = read(filenamesec_d)
    write(f, sec)

    #write the return part
    write(f, "\n\n")
    write(f, "return (")
    for i=1:NB_prim
        write(f, "d", prefprim, "$i,")
    end
    write(f, "), (")
    for i=1:NB_secondary
        write(f, "d", prefsec, "$i,")
    end
    write(f, ")\n end")

# -------------------------------------------
#
# Generate both invariants and derivatives of the invariants
#
# -------------------------------------------
    write(f, "\n\n\n\n")
    write(f, "function invariants_ed_gen(x1::SVector{$NBlengths, T}) where {T}\n")
    for i=2:max(max_exp_irrsec,max_exp_prim)
        im = i-1;
        write(f, "   x$i = x$im.*x1 \n")
    end
    write(f, "\n   dx1 = @SVector ones($NBlengths)\n")
    for i=2:max(max_exp_irrsec,max_exp_prim)
        im = i-1;
        write(f, "   dx$i = $i * x$im \n")
    end

    # write the primary invariants
    write(f, "   #------------------------------------------------\n")
    write(f, "   # Primaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n")
    prim5 = read(filenameprim5)
    write(f, prim5)

    # write the irreducible secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # Irreducible secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    irrsec5 = read(filenameirrsec5)
    write(f, irrsec5)

    # write all the secondary invariants
    write(f, "\n\n\n   #------------------------------------------------\n")
    write(f, "   # All secondaries\n")
    write(f, "   #------------------------------------------------\n")

    write(f, "\n\n")
    sec = read(filenamesec)
    write(f, sec)

    write(f, "\n\n")
    sec = read(filenamesec_d)
    write(f, sec)

    #write the return part
    write(f, "\n\n")
    write(f, "return (@SVector [")
    for i=1:NB_prim
        write(f, prefprim, "$i,")
    end
    write(f, "]), (@SVector [")
    for i=1:NB_secondary
        write(f, prefsec, "$i,")
    end
    write(f, "]), (@SVector [")
    for i=1:NB_prim
        write(f, "d", prefprim, "$i,")
    end
    write(f, "]), (@SVector [")
    for i=1:NB_secondary
        write(f, "d", prefsec, "$i,")
    end
    write(f, "])\n end")


# Generate monomials with weights: for primaries, irreducible secondaries, and secondaries
# for irreducible secondaries
Mon_irrsec, coef_list_irrsec = generate_inv_mon(filenameirrsecdata,NBlengths,Deg)
# for primaries
Mon_prim, coef_list_prim = generate_inv_mon(filenameprimdata,NBlengths,Deg)

Mon_sec = []
coef_sec = []

fileI = open(filenamesec)
line = readlines(fileI)
# first line contains sec invariant =1, we remove it
for i=2:length(line)
    part1,part2 = split(line[i], "=")
    Part1 = replace(part1, prefsec, "")
    @assert parse(Int64,Part1) == i
    if contains(line[i], "*")
        part2_1,part2_2 = split(part2, "*")
        Part2_1 = replace(part2_1, prefirrsec, "")
        Part2_2 = replace(part2_2, prefirrsec, "")
        int1 = parse(Int64,Part2_1)
        int2 = parse(Int64,Part2_2)
        Mon_irrsec1 = [Mon_irrsec[int1]]
        coef_list_irrsec1 = [coef_list_irrsec[int1]]
        Mon_irrsec2 = [Mon_irrsec[int2]]
        coef_list_irrsec2 = [coef_list_irrsec[int2]]
        mon_list_out,coef_list_out = prod_mon_comp(Mon_irrsec1,coef_list_irrsec1,Mon_irrsec2,coef_list_irrsec2)
        push!(Mon_sec,mon_list_out)
        push!(coef_sec,coef_list_out)
    else
        Part2 = replace(part2, prefirrsec, "")
        int = parse(Int64,Part2)
        push!(Mon_sec,[(Mon_irrsec[int])])
        push!(coef_sec,[(coef_list_irrsec[int])])
    end
end
Mon_sec[1]
coef_sec


invariant_tuples = NBodyIPs.gen_tuples(NBody,Deg)
basis_fcts_mon = generate_rep_mon(NBlengths,Deg)
@assert length(inv_tuples) == length(basis_fcts_mon)

M_basis_change = zeros(Int64,length(inv_tuples),length(inv_tuples))
# express all inv_tuples in terms of monomials

Mon_basis_fcts = []
coef_basis_fcts = []

for i=1:length(inv_tuples)
    tup = invariant_tuples[i]
    ind_tup_non_zero = find(tup)
    mon_tup = []
    coef_tup = []
    for k=1:(NBlengths-1)
        if tup[k] != 0
            if mon_tup != []
                @show mon_tup
                @show coef_tup
                @show length([Mon_prim[k]])
                @show length(coef_list_prim[k])
                mon_tup = prod_mon_comp(mon_tup,coef_tup,[Mon_prim[k]],[coef_list_prim[k]])
            else
                mon_tup = [Mon_prim[k]]
                coef_tup = [coef_list_prim[k]]
            end
        end
    end
    if tup[NBlengths] != 0
        if mon_tup != []
            mon_tup = prod_mon_comp(mon_tup,coef_tup,Mon_sec[tup[NBlengths]],coef_list_sec[tup[NBlengths]])
        else
            mon_tup = Mon_sec[tup[NBlengths]]
            coef_tup = coef_list_sec[tup[NBlengths]]
        end
    end
    push!(Mon_basis_fcts,mon_tup)
    push!(coef_basis_fcts,coef_tup)
end

mon_list,coef_list = power(USP,[1,1,1,1,1,1],3)

compact_form_mon(mon_list,coef_list)


USP = unique(simplex_permutations(SVector(Mon...)))

check_dupl_add([USP; USP],[1,2,3,4,5,6,1,2,3,4,5,6])

compact_form_mon(USP)

prod_mon(USP,[1,1,1,1,1,1], USP,[1,1,1,1,1,1])


compact_form_mon([USP; USP],[1,1,1,1,1,1,2,2,2,2,2,2])

expanded_form_mon([Mon],[1])


#Remove the temporary files
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text1.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text2.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text3.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_irr_sec_text4.jl");

rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text1.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text2.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text3.jl");
rm("magma/data/NB_$NBody"*"_deg_$Deg"*"/NB_$NBody"*"_deg_$Deg"*"_prim_text4.jl");

end
