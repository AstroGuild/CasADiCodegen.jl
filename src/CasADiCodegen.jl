"""
    CasADiCodegen

Julia code generation for CasADi functions.

The package works with the official CasADi front end for Julia, CasADiNative.jl.
`build_function` and `generate_julia` turn a CasADi `Function` into plain Julia code.
Loading the package also makes a number in a Dict of options reach CasADi with
its type, where the front end makes it a `bool`.
"""
module CasADiCodegen

import CasADiNative
import CasADiSWIG_jll
import Libdl
using PrecompileTools: @compile_workload

# The generated module of the front end, whose functions take the Dicts of options.
const C = CasADiNative.C

include("options.jl")
Base.include_dependency(CasADiSWIG_jll.casadi_jl)
for signature in option_signatures(CasADiSWIG_jll.casadi_jl), definition in typed_methods(signature)
    Core.eval(@__MODULE__, definition)
end

include("codegen.jl")

using .Codegen: build_function, generate_julia, instruction_histogram, nan_trace, differentiable, Solvers, Solver

export build_function, generate_julia

include("precompile.jl")

end # module CasADiCodegen
