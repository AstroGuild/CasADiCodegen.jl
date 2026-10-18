# Replace the solvers of CasADi

A model that already exists often holds solver objects of CasADi itself: an
integrator made with `CasADiCodegen.C.integrator(name, "cvodes", ...)`, a rootfinder, or a solver
of `nlpsol`. Generated code never calls CasADi, so such an object needs a solver
of the SciML ecosystem. You need SciMLBase.jl and the package of the algorithm.

The examples use an integrator `cvodes` for the planar two-body problem:

```@example solvers
using CasADiCodegen
using OrdinaryDiffEqVerner: Vern9
import SciMLBase

x, mu = MX.sym("x", 4), MX.sym("mu")
r3 = (x[1]^2 + x[2]^2)^1.5
ode = vertcat(x[3], x[4], -mu * x[1] / r3, -mu * x[2] / r3)
I = CasADiCodegen.C.integrator("I", "cvodes", Dict("x" => x, "p" => mu, "ode" => ode), 0.0, [1.0, 2.0, 3.0])
nothing # hide
```

## Replace a solver in generated code

Give `build_function` or `generate_julia` the keyword `solvers` with a
[`CasADiCodegen.Solvers`](@ref). Each field holds an algorithm, or a
[`CasADiCodegen.Solver`](@ref) when the algorithm has options.

```@example solvers
using CasADiCodegen: Solvers, Solver

x0, p = MX.sym("x0", 4), MX.sym("p")
final = I(Dict("x0" => x0, "p" => p))["xf"]                    # 4 by 3: one column per output time
f = CasADiCodegen.Function("f", [x0, p], [final, jacobian(final[:, 3], x0)])

solvers = Solvers(ode = Solver(Vern9(); abstol = 1e-13, reltol = 1e-13))
g, g! = build_function(f; expression = Val{false}, solvers)
states, stm = g([1.0, 0.0, 0.0, 1.0], [1.0])
states
```

Without `solvers`, `build_function` throws an `ArgumentError` that names the
function and the field of `Solvers` to set.

| Field of `Solvers` | Replaces | With |
|---|---|---|
| `ode` | Integrator `cvodes` | An ODE algorithm. Supported: quadratures, controls (the input `u` of a CasADi integrator, constant between two output times), several output times, forward and adjoint sensitivities, derivatives of any order, event functions (see [Integrators with events](@ref)) |
| `dae` | Integrator `idas` with algebraic states | An algorithm that accepts a mass matrix, such as `Rodas5P()`; the same derivatives |
| `nonlinear` | Rootfinders `kinsol` and `fast_newton` | A nonlinear algorithm, as for `rootfinder` |
| `optimization` | Solvers of `nlpsol` and of `conic` (quadratic problems; no cone constraints) | An algorithm of Optimization.jl, such as `Ipopt.Optimizer()` with OptimizationMOI.jl |
| `overrides` | One object each: a tuple of `Solver(object, alg; options...)` | The solver for that object and its derivatives; it has priority, and it is the only way to replace `rk`, `collocation` or `newton`, which have Julia code of their own |

`object` is the solver object of CasADi itself. The two examples below replace one
integrator `R` by name, and a solver of `nlpsol`:

```julia
R = CasADiCodegen.C.integrator("R", "rk", Dict("x" => x, "p" => mu, "ode" => ode), 0.0, 1.0)
solvers = Solvers(overrides = (Solver(R, Vern9(); abstol = 1e-12),))

import Ipopt, OptimizationMOI
ipopt = OptimizationMOI.MOI.OptimizerWithAttributes(Ipopt.Optimizer, "print_level" => 0, "tol" => 1e-12)
solvers = Solvers(optimization = ipopt)
```

## What a replaced solver does

The code uses the tolerances of the integrator of CasADi, unless the `Solver(...)`
gives `abstol` or `reltol`. An integrator or a rootfinder
becomes an `integrator` or a `rootfinder` of this package, so the code takes dual
numbers and CasADi gets its derivatives as for those functions. An integrator with
an event function is the exception (see [Integrators with events](@ref)).

For a solver of `nlpsol`, the generated code solves the problem with the bounds of
the call and then computes the multipliers in the form that CasADi expects:
the multiplier of a bound that is not active is exactly zero, and the others solve
the stationarity condition by least squares. CasADi makes the derivatives of the
solution from these results, since it reads the active bounds from the signs of the
multipliers, so that derivatives of any order need no other code. A bound counts as
active when the solution is within 1e-6 of it, relative to the bound when that is
more than 1. The problem is solved with `Float64` only, with dense matrices, and the
first guesses of the multipliers are not used. The options that the solver of CasADi
has, such as those of `ipopt`, are not read: give them with the algorithm.

`generate_julia` writes a replaced solver to the module under the rule for
integrators (see [Write the model to a file](@ref)): the algorithm and its options
must be values that a source file can hold.

Reverse mode works through an integrator that a solver replaces, since CasADi gets
the adjoint sensitivities as the reverse derivative of the chain of calls between
the output times. Each call integrates the adjoint equations backward, as `integrator`
does with `adjoint = true`, also for a model with algebraic states.

## Integrators with events

An integrator of CasADi whose model has the entry `"zero"` has event functions, and
its option `"transition"` gives the state after an event. The generated code
replaces it by one Julia function that integrates to all the output times with the
solver of the field `ode`, or `dae` for algebraic states; an integrator `rk` or
`collocation` with events needs an override. The events follow the rules of CasADi:
an event is a change of sign of an element of `"zero"` from positive to negative,
the transition then sets the state, and a call throws after more than
`max_events` events of CasADi (20 by default). The numbers must be `Float64`,
because the solver does not take dual numbers through an event.

```julia
h, v, e = MX.sym("h"), MX.sym("v"), MX.sym("e")             # height, speed, restitution
model = Dict("x" => vertcat(h, v), "p" => e, "ode" => vertcat(v, -9.81), "zero" => h)
bounce = CasADiCodegen.C.Function("transition", Dict("x" => vertcat(h, v), "p" => e, "post_x" => vertcat(h, -e * v)),
                           CasADiCodegen.C.event_in(), CasADiCodegen.C.event_out())
ball = CasADiCodegen.C.integrator("ball", "cvodes", model, 0.0, [0.5, 1.0, 2.0], Dict("transition" => bounce))
```

CasADi differentiates such an integrator by forward directions only, and the
generated code moves the derivatives at each event by the derivative of the event
time, from the implicit function theorem, and by the derivative of the transition.
The function `jacobian` of CasADi gives the Jacobian of the integrator the sparsity
pattern of the model without events, which omits the effect of the transitions.
Use directional derivatives with one direction per argument instead:

```julia
s0, q = MX.sym("s0", 2), MX.sym("q")
final = CasADiCodegen.C.vec(ball(Dict("x0" => s0, "p" => q))["xf"])
arguments = vertcat(s0, q)
J = CasADiCodegen.C.jtimes(final, arguments, MX(CasADiCodegen.C.DM([Float64(i == j) for i in 1:3, j in 1:3])))
f = CasADiCodegen.Function("f", [s0, q], [final, CasADiCodegen.C.densify(J)])
```

CasADi has no reverse mode through an integrator with events, and the derivatives
of one with algebraic states are refused.

## Solve the problem yourself

To call the solver yourself, make a SciML problem from the solver object of CasADi.
The problem holds generated code for its functions and their derivatives:

```@example solvers
problem = SciMLBase.ODEProblem(I, [1.0, 0.0, 0.0, 1.0], [1.0])    # the output times of I are `saveat`
solution = SciMLBase.solve(problem, Vern9(); abstol = 1e-13, reltol = 1e-13)
solution.u[end]
```

| Constructor | Object of CasADi | Problem |
|---|---|---|
| `ODEProblem(I, x0, p; z0, u)` | Integrator `cvodes`, `idas`, `rk` or `collocation` | The state has the differential states, the algebraic states from the guess `z0` and the quadratures; algebraic states give a mass matrix; event functions give a callback with the transition; the tolerances of CasADi are `abstol` and `reltol` |
| `NonlinearProblem(R, z0, others...)` | Rootfinder `newton`, `fast_newton` or `kinsol` | The residual and its Jacobian; the other arguments of `R` are the parameters |
| `OptimizationProblem(S, x0, p; lbx, ubx, lbg, ubg)` | Solver of `nlpsol` or of `conic` | The objective and the constraints with their derivatives; the bounds have the names and the default values of CasADi. For `conic`, `p` has the nonzeros of `h`, then `g`, then the nonzeros of `a` |


For an integrator with controls and several output times, `u` has one block of controls
per output time, and the problem has a callback that changes the controls at each
output time.

## Limits

[What is refused](@ref) lists each object that has no replacement, with what to do.
