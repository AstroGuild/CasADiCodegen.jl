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
CasADiCodegen.callback(::Any, ::AbstractString, ::Tuple, ::Tuple)
CasADiCodegen.integrator(::AbstractString, ::SciMLBase.AbstractODEAlgorithm, ::Any, ::Real, ::Real)
CasADiCodegen.rootfinder(::AbstractString, ::SciMLBase.AbstractNonlinearAlgorithm, ::CasADiCodegen.Function)
```

## Solvers of CasADi

```@docs
CasADiCodegen.Solvers
CasADiCodegen.Solver
SciMLBase.ODEProblem(::CasADiCodegen.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})
SciMLBase.NonlinearProblem(::CasADiCodegen.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real}...)
SciMLBase.OptimizationProblem(::CasADiCodegen.Function, ::AbstractVector{<:Real}, ::AbstractVector{<:Real})
```

## Functions of SciML problems

```@docs
SciMLBase.ODEFunction(::CasADiCodegen.Function)
SciMLBase.NonlinearFunction(::CasADiCodegen.Function)
SciMLBase.OptimizationFunction(::CasADiCodegen.Function, ::Union{Nothing,CasADiCodegen.Function})
```

## Automatic differentiation rules and sparse matrices

```@docs
CasADiCodegen.differentiable
SparseArrays.SparseMatrixCSC(::CasADiCodegen.Sparsity)
```

## Inspection

```@docs
CasADiCodegen.instruction_histogram
CasADiCodegen.nan_trace
```
