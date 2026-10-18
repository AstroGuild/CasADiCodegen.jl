# CasADiCodegen.jl

[CasADi](https://web.casadi.org/) is a framework for symbolic modelling and
algorithmic differentiation, designed primarily for nonlinear optimization and
optimal control. CasADiCodegen.jl generates ordinary Julia functions from CasADi
models, including derivatives computed by CasADi. The models are written with
[CasADiNative.jl](https://github.com/casadi/CasADiNative.jl), the official Julia
front end of CasADi.

Use CasADiCodegen.jl when you want to define a model with CasADi, or load one created in
Python, MATLAB, or C++, and then run the model and its derivatives as Julia code.
The generated functions accept Julia arrays, so you can call them directly from
simulation, optimization, or other Julia code.

## Installation

CasADiCodegen.jl supports Julia 1.12 and 1.13. After you activate the environment where
you want to use it, install the package directly from GitHub:

```julia-repl
pkg> add https://github.com/casadi/CasADiNative.jl
pkg> add https://github.com/EllissoideRotondo/CasADiCodegen.jl
```

## Quick start

Define a symbolic function and its gradient, then build Julia functions that
evaluate both:

```julia
using CasADiNative, CasADiCodegen

x = SX.sym("x", 2)
y = x[1]^2 + sin(x[2])
f = CasADiNative.Function("f", [x], [y, gradient(y, x)])

f_julia, f_julia! = build_function(f; expression = Val(false))
value, derivative = f_julia([2.0, 0.0])

value       # [4.0]
derivative  # [4.0, 1.0]
```

`using CasADiNative` loads the Julia front end, including `SX`, `MX`, and symbolic
operations such as `gradient` and `jacobian`. Write `CasADiNative.Function` explicitly
because `Function` is already a Julia type.

`expression = Val(false)` makes `build_function` return callable functions for the
current session: `f_julia` allocates its outputs, while `f_julia!` writes into
arrays that you supply. Use [`generate_julia`](docs/src/api.md#code-generation) to
write the generated functions to a Julia module instead.

## Documentation

See [Getting started](docs/src/tutorial.md) for the complete code-generation
workflow. The manual also describes [supported models and
limitations](docs/src/explanation/scope.md) and provides an [API
reference](docs/src/api.md).
