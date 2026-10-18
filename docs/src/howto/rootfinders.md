# Solve an equation

[`CasADiCodegen.rootfinder`](@ref) makes a CasADi function that solves
`f(z, p1, p2, ...) = 0` for `z` with a nonlinear solver of the SciML ecosystem, so
that a model can contain the solution of an implicit equation together with its
derivatives. The residual `f` is a CasADi function whose result has the size of `z`.

`rootfinder` is the function of the CasADi front end. The method that takes a SciML
algorithm exists once a solver package is loaded, for example SimpleNonlinearSolve.jl.

We solve the equation of Kepler for the eccentric anomaly, and generate the root
with its derivative by the mean anomaly:

```@example root
using CasADiCodegen
using SimpleNonlinearSolve: SimpleNewtonRaphson

E, M, e = SX.sym("E"), SX.sym("M"), SX.sym("e")
kepler = CasADiCodegen.Function("kepler", [E, M, e], [E - e * sin(E) - M])
anomaly = rootfinder("anomaly", SimpleNewtonRaphson(), kepler; abstol = 1e-14)

m, ec = MX.sym("m"), MX.sym("ec")
root = anomaly(m, m, ec)                      # the mean anomaly is the first guess
f = CasADiCodegen.Function("f", [m, ec], [root, jacobian(root, m)])
g, g! = build_function(f; expression = Val{false})
g([1.0], [0.3])
```

The function takes a first guess of `z` and then the other arguments of `f`, and it
returns the root. All keywords, such as `abstol` and `maxiters`, go to the solver.

## Derivatives

CasADi differentiates the root to any order, because the implicit function theorem
gives its Jacobian as the solution of a linear system at the root, which is an
ordinary CasADi expression. The generated code calls the solver directly, on static
arrays. Measured once on Julia 1.13, `g!` of the example takes 0.13 µs and allocates
no memory, also with the second derivative by `m` as a third result.

`generate_julia` writes a function with a rootfinder to a module under the rule for
integrators; see [Write the model to a file](@ref).

A rootfinder of CasADi itself, made with a solver name such as `"kinsol"`, also works
in generated code. The package generates Julia code for `newton`, and `kinsol` and
`fast_newton` need a SciML solver; see [Replace the solvers of CasADi](@ref).
