# Solve an equation

[`CasADiCodegen.rootfinder`](@ref) makes a CasADi function that solves `f(z, p1, p2, ...) = 0`
for `z` with a nonlinear solver of the SciML ecosystem. The residual `f` is a CasADi
function whose result has the size of `z`. Add a solver package to your environment,
for example SimpleNonlinearSolve.jl: `rootfinder` has no methods until one is loaded.

The example solves the equation of Kepler for the eccentric anomaly:

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

The function takes a first guess of `z` and then the other arguments of `f`, and
returns the root. The keywords go to the solver.

## Derivatives

CasADi differentiates the root to any order, because the implicit function theorem
gives its Jacobian as the solution of a linear system at the root, which is an
ordinary CasADi expression. The generated code calls the solver directly, on static
arrays: for the root with its derivative and its Hessian, `g!` takes 0.2 µs and
allocates no memory.

`generate_julia` writes a function with a rootfinder to a module under the rule for
integrators: see [Write the model to a file](@ref).

To generate code for a rootfinder of CasADi itself (`newton`, `kinsol`,
`fast_newton`), see [Replace the solvers of CasADi](@ref).
