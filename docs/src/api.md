# API reference

This page lists the functions and types of CasADiCodegen.jl, grouped by task. The
package exports `build_function`, `generate_julia` and `CasadiFunction`, and `using CasADiCodegen`
also gives the names that the front end of CasADi exports, such as `SX`, `MX`,
`jacobian` and `vertcat`. The other names of this page need the prefix
`CasADiCodegen.`, except `callback`, `integrator` and `rootfinder`, which are
exported functions of the front end to which the package adds methods.

## Code generation

```@docs
CasadiFunction
build_function
generate_julia
```

## Julia functions inside a model

```@docs
CasADiCodegen.callback(::Any, ::AbstractString, ::Tuple, ::Tuple)
```

## SciML solvers inside a model

`integrator` and `rootfinder` are the functions of the CasADi front end. With a
solver name such as `"cvodes"` or `"kinsol"`, they make a solver object of CasADi
itself, as in Python. The methods below take a SciML algorithm instead; they exist
once SciMLBase.jl is loaded, which each SciML solver package does.

```@docs
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
