# CasADiCodegen.jl

CasADiCodegen.jl turns a CasADi function into plain Julia code. You write the model with
the official CasADi front end, CasADi computes the derivatives, and the package
emits Julia functions that run without CasADi.

!!! warning "Integer options before version 0.26.0"
    Before version 0.26.0, an integer or a whole `Float64` in a Dict of options,
    such as `"number_of_finite_elements" => 7`, reached CasADi as `true`, that is 1.
    Compute again the results of a model with such an option. Your code needs no
    change. See [Numbers in a Dict of options](@ref).

## Where to go

| You want to | Read |
|---|---|
| Generate your first function | [Getting started](@ref) |
| Use a model written in Python, MATLAB or C++ | [Load a model from another language](@ref) |
| Call your own Julia code from a model | [Call a Julia function from the model](@ref) |
| Integrate an ODE inside a model, with derivatives | [Integrate a differential equation](@ref) |
| Stop an integration at an event | [Stop at an event](@ref events) |
| Solve an implicit equation inside a model | [Solve an equation](@ref) |
| Generate code for a model that holds `cvodes`, `idas`, `kinsol` or `nlpsol` | [Replace the solvers of CasADi](@ref) |
| Use a CasADi function in a SciML problem | [Give a CasADi function to a SciML problem](@ref) |
| Shorten compile time of a large model | [Large functions and the cache on disk](@ref) |
| Give the generated derivatives to Zygote.jl and others | [Use the generated derivatives from an AD package](@ref) |
| Find a slow operation or the source of a NaN | [Inspect a model](@ref) |
| Understand matrix (MX) code and `expand = false` | [Matrix code and functions without instructions](@ref) |
| Understand how an integrator gets its derivatives | [How an integrator is differentiated](@ref) |
| Know what is supported | [Scope and differences from CasADi](@ref) |
| Look up a function | [API reference](@ref) |

## Install

The package supports Julia 1.12 and 1.13. Install CasADiNative.jl and the package from
GitHub:

```julia-repl
pkg> add https://github.com/casadi/CasADiNative.jl
pkg> add https://github.com/EllissoideRotondo/CasADiCodegen.jl
```
