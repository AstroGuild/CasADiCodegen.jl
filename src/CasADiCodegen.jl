"""
    CasADiCodegen

The official CasADi front end for Julia, plus Julia code generation.

The module includes the SWIG-generated front end that ships with CasADi;
`CasADiCodegen.C` is the generated module. It has two changes: a number in a Dict of
options reaches CasADi with its type, where the generated code makes it a `bool`, and
`jacobian` of a graph with an integrator with an event function gives the Jacobian of
forward directions, where CasADi gives a wrong one. The package adds
`build_function` and `generate_julia`, which turn a CasADi `Function` into
plain Julia code.
"""
module CasADiCodegen

import CasADi_jll
import CasADiSWIG_jll
import Libdl
using PrecompileTools: @compile_workload

# The official front end: the generated module `casadi`, its alias `C`, the
# convenience layer and its exports (`SX`, `MX`, `jacobian`, ...), with the changes
# of front_end.jl.
include("options.jl")
include("front_end.jl")
Base.include_dependency(CasADiSWIG_jll.casadi_native_body)
Base.include_dependency(CasADiSWIG_jll.casadi_jl)
include(typed_front_end, CasADiSWIG_jll.casadi_native_body)

include("codegen.jl")

using .Codegen: build_function, generate_julia, instruction_histogram, nan_trace, differentiable, Solvers, Solver

export build_function, generate_julia

include("precompile.jl")

end # module CasADiCodegen
