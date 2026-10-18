# Give a CasADi function to a SciML problem

With SciMLBase.jl loaded, a CasADi function becomes the function of a SciML
problem. The problem holds generated code for the function and for the derivatives
that the solvers ask for, so no automatic differentiation runs at solve time, and
each generated function works in place and allocates no memory.

## Solve an ODE

We write the right side of a harmonic oscillator as a CasADi function of the state,
the parameter and the time, and give it to `ODEFunction`:

```@example sciml
using CasADiCodegen
using OrdinaryDiffEqVerner: Vern9
import SciMLBase

u, k, t = SX.sym("u", 2), SX.sym("k"), SX.sym("t")
rhs = CasADiCodegen.Function("rhs", [u, k, t], [vertcat(u[2], -k * u[1])])     # also f(u) and f(u, p)
problem = SciMLBase.ODEProblem(SciMLBase.ODEFunction(rhs), [1.0, 0.0], (0.0, pi), [4.0])
SciMLBase.solve(problem, Vern9(); abstol = 1e-12, reltol = 1e-12).u[end]
```

## Other problems

The constructors of nonlinear and optimization problems follow the same pattern.
We solve two equations in `z` with the parameter `q`:

```@example sciml
using SimpleNonlinearSolve: SimpleNewtonRaphson

z, q = SX.sym("z", 2), SX.sym("q")
residual = CasADiCodegen.Function("r", [z, q], [vertcat(z[1]^2 + z[2]^2 - q, z[1] - z[2])])   # also f(z)
problem = SciMLBase.NonlinearProblem(SciMLBase.NonlinearFunction(residual), [1.0, 0.5], [2.0])
SciMLBase.solve(problem, SimpleNewtonRaphson(); abstol = 1e-12).u
```

For an optimization problem, the objective is one number and the constraints are one
vector, with the same arguments. The constraints are optional; with them, the problem
takes their bounds `lcons` and `ucons`. The function holds its derivatives, so the
problem needs no `adtype`:

```@example sciml
v = SX.sym("v", 2)
objective = CasADiCodegen.Function("J", [v, q], [(v[1] - q)^2 + v[2]^2])     # also f(v)
constraints = CasADiCodegen.Function("c", [v, q], [vertcat(v[1] + v[2])])
f = SciMLBase.OptimizationFunction(objective, constraints)
problem = SciMLBase.OptimizationProblem(f, [0.0, 0.0], [1.0]; lcons = [1.0], ucons = [Inf])
nothing # hide
```

A solver of Optimization.jl, such as Ipopt through OptimizationMOI.jl, then solves
`problem`.

Each CasADi function takes the unknowns first and then, optionally, the parameters.

| Constructor | Generated functions |
|---|---|
| `ODEFunction(f; jac = true, paramjac = true)` | Right side, `jac`, and `paramjac` when `f` has parameters |
| `NonlinearFunction(f; jac = true)` | Residual and `jac` |
| `OptimizationFunction(objective, constraints)` | Objective, `grad`, `hess`, `cons`, `cons_j` and `cons_h`, the Hessian of each constraint |

- The matrices are dense.
- The other keywords go to the SciML constructor.
- A function that has no parameters ignores the parameters of the problem.
- `OptimizationFunction` gives no Hessian of the Lagrange function (`lag_h`). The
  solvers of Optimization.jl make it from `hess` and `cons_h`.

For the problem of a solver object of CasADi (`cvodes`, `kinsol`, `nlpsol`), see
[Solve the problem in Julia](@ref).
