# Trace a model written in Julia

A model that exists as generic Julia code, written for any subtype of `Real`, can
enter a CasADi graph without being rewritten. [`CasADiCodegen.Traced`](@ref) is a
real number that records each operation on it as a CasADi expression, as the `Num`
of Symbolics.jl does, so that calling the Julia function on traced values gives the
graph of the function, which CasADi then differentiates and CasADiCodegen.jl emits.

We trace the two-body acceleration, written with a static vector and `norm`, and
generate its value and its Jacobian:

```@example traced
using CasADiCodegen, LinearAlgebra, StaticArrays

acceleration(r, μ) = -μ * r / norm(r)^3          # generic Julia code

r = SX.sym("r", 3)
a = CasADiCodegen.untraced(acceleration(SVector{3}(CasADiCodegen.traced(r)), 398600.4418))
f = CasadiFunction("a", [r], [a, jacobian(a, r)])
g, g! = build_function(f; expression = Val{false})
value, J = g([7000.0, -1200.0, 300.0])
J
```

[`CasADiCodegen.traced`](@ref) turns a symbolic column vector into a vector of traced
values, and [`CasADiCodegen.untraced`](@ref) turns the result back into a column
vector of CasADi, on which `jacobian`, `hessian` and the other functions of CasADi
work. A plain number in the code becomes a constant of the graph, and a loop with a
fixed number of steps is unrolled into it.

## Choices that depend on the input

A comparison of traced values gives a traced condition, not a `Bool`. An `if`, a
`&&` or a `? :` on such a condition therefore throws a `TypeError`, instead of
following the branch that the values at the time of the trace select and
differentiating only that branch. A choice that depends on the input is written
with `ifelse`, `min`, `max` or `clamp`, which become the operations `if_else`,
`fmin` and `fmax` of CasADi and keep both branches in the graph:

```@example traced
x = SX.sym("x")
t = only(CasADiCodegen.traced(x))
thrust = CasADiCodegen.untraced(ifelse(t > 0, clamp(2t, 0, 1), 0.0))
h, _ = build_function(CasadiFunction("thrust", [x], [thrust]); expression = Val{false})
h([0.2]), h([0.8]), h([-1.0])
```

A Julia function with branches that cannot be written this way, or one that calls
code that accepts only `Float64`, enters the graph through
[`CasADiCodegen.callback`](@ref) instead (see [Call a Julia function from the model](@ref)).

## Matrix graphs

`traced` also takes a column vector of a matrix (MX) graph. The traced values are
then `Traced{MX}`, and the generic code can work on the results of a callback or of
any other MX expression, while the graph stays a matrix graph.
