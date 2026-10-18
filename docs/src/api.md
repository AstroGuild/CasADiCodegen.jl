# API reference

`build_function` and `generate_julia` are exported. The other names need the prefix
`CasADiCodegen.`, except `callback`, `integrator` and `rootfinder`, which are functions of
the CasADi front end that this package extends.

## Code generation

```@docs
build_function
generate_julia
```

## Julia code inside a model

The methods of `integrator` and `rootfinder` exist when SciMLBase.jl is loaded, which each SciML solver package does.

```@docs
CasADiNative.callback(::Any, ::AbstractString, ::Tuple, ::Tuple)
CasADiNative.integrator(::AbstractString, ::SciMLBase.AbstractODEAlgorithm, ::Any, ::Real, ::Real)
CasADiNative.rootfinder(::AbstractString, ::SciMLBase.AbstractNonlinearAlgorithm, ::CasADiNative.Function)
```

## Solvers of CasADi

```@docs
CasADiCodegen.Solvers
CasADiCodegen.Solver
SciMLBase.ODEProblem(::CasADiNative.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})
SciMLBase.NonlinearProblem(::CasADiNative.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real}...)
SciMLBase.OptimizationProblem(::CasADiNative.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})
```

## Functions of SciML problems

```@docs
SciMLBase.ODEFunction(::CasADiNative.Function)
SciMLBase.NonlinearFunction(::CasADiNative.Function)
SciMLBase.OptimizationFunction(::CasADiNative.Function, ::Union{Nothing,CasADiNative.Function})
```

## Automatic differentiation rules and sparse matrices

```@docs
CasADiCodegen.differentiable
SparseArrays.SparseMatrixCSC(::CasADiNative.Sparsity)
```

## Inspection

```@docs
CasADiCodegen.instruction_histogram
CasADiCodegen.nan_trace
```
