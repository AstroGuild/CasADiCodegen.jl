# Give a CasADi function to a SciML problem

With SciMLBase.jl loaded, a CasADi function becomes the function of a SciML
problem. It holds generated code for the function and for the derivatives that
the solvers ask for, so no automatic differentiation runs at solve time. Each
generated function works in place and allocates no memory.

```@example sciml
using CasADiNative, CasADiCodegen
using OrdinaryDiffEqVerner: Vern9
import SciMLBase

u, k, t = SX.sym("u", 2), SX.sym("k"), SX.sym("t")
rhs = CasADiNative.Function("rhs", [u, k, t], [vertcat(u[2], -k * u[1])])     # also f(u) and f(u, p)
problem = SciMLBase.ODEProblem(SciMLBase.ODEFunction(rhs), [1.0, 0.0], (0.0, pi), [4.0])
SciMLBase.solve(problem, Vern9(); abstol = 1e-12, reltol = 1e-12).u[end]
```

The other constructors follow the same pattern:

```julia
residual = CasADiNative.Function("r", [z, q], [equations])        # also f(z)
problem = SciMLBase.NonlinearProblem(SciMLBase.NonlinearFunction(residual), z0, q0)

objective = CasADiNative.Function("J", [v, q], [cost])            # also f(v); one number
constraints = CasADiNative.Function("c", [v, q], [limits])        # the same arguments; one vector
f = SciMLBase.OptimizationFunction(objective, constraints)  # constraints are optional
```

Each CasADi function takes the unknowns first and then, optionally, the parameters.

| Constructor | Generated functions |
|---|---|
| `ODEFunction(f; jac = true, paramjac = true)` | Right side, `jac`, and `paramjac` when `f` has parameters |
| `NonlinearFunction(f; jac = true)` | Residual and `jac` |
| `OptimizationFunction(objective, constraints)` | Objective, `grad`, `hess`, `cons`, `cons_j` and `cons_h`, the Hessian of each constraint |

The matrices are dense, and the other keywords go to the SciML constructor. A function
that has no parameters ignores the parameters of the problem.

`OptimizationFunction` gives no Hessian of the Lagrange function (`lag_h`): the
solvers of Optimization.jl make it from `hess` and `cons_h`.

For the problem of a solver object of CasADi (`cvodes`, `kinsol`, `nlpsol`), see
[Solve the problem yourself](@ref).
