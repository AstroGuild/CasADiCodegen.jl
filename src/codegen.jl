"""
    Codegen

Everything that this package adds to the CasADi front end.

It is a separate module because the front end shadows 44 names of `Base`
inside `CasADiCodegen` (`all`, `sum`, `sin`, `zeros`, ...). Inside `Codegen` those
names keep their ordinary meaning.
"""
module Codegen

using RuntimeGeneratedFunctions: RuntimeGeneratedFunctions, RuntimeGeneratedFunction
import LinearAlgebra
import NaNMath
import SpecialFunctions
import StaticArrays
import StaticArraysCore

RuntimeGeneratedFunctions.init(@__MODULE__)

# A second context for the runtime generated functions that a generated function calls
# inside a SciML solver. Each context has its own method of `generated_callfunc`; with
# one method, inference sees the residual of a rootfinder as a recursion of the function
# that calls the solver, widens the call and boxes its arguments.
module Nested
import ..RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)
end

"The context module of the runtime generated functions that `build_function` makes."
const CONTEXT = Base.ScopedValues.ScopedValue{Module}(@__MODULE__)

const Front = parentmodule(@__MODULE__)
const C = Front.C
const SX = C.SX
const MX = C.MX

include("contracts.jl")
include("operations.jl")
include("algorithm.jl")
include("read_algorithm.jl")
include("callback.jl")
include("c_code.jl")
include("external.jl")
include("problems.jl")
include("mx_algorithm.jl")
include("overloads.jl")
include("emit.jl")
include("mx_emit.jl")
include("source.jl")
include("forms.jl")
include("staged.jl")
include("newton.jl")
include("integrator.jl")
include("rootfinder.jl")
include("tools.jl")
include("rules.jl")
include("cache.jl")

end # module Codegen
