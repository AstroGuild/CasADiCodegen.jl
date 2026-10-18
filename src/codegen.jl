"""
    Codegen

The code generation of the package, which reads functions of the front end
CasADiNative.jl (`Front` here) and emits Julia code.
"""
module Codegen

using RuntimeGeneratedFunctions: RuntimeGeneratedFunctions, RuntimeGeneratedFunction
import LinearAlgebra
import NaNMath
import SpecialFunctions
import StaticArrays
import StaticArraysCore

RuntimeGeneratedFunctions.init(@__MODULE__)

import CasADiNative

const Package = parentmodule(@__MODULE__)
const Front = CasADiNative
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
