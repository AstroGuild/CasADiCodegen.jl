# Integrate a differential equation

[`CasADiCodegen.integrator`](@ref) makes a CasADi function that integrates an ordinary
differential equation with a solver of the SciML ecosystem. CasADi differentiates it
to any order, and the generated code calls the solver directly.

Add a solver package to your environment, for example OrdinaryDiffEqVerner.jl.
The bare name `integrator` is the function of this page, which takes a SciML
algorithm. The integrators of CasADi itself (`"cvodes"`, `"rk"`, ...) come from
`CasADiCodegen.C.integrator`; see [Replace the solvers of CasADi](@ref). The examples use the
planar two-body problem:

```@example ode
using CasADiCodegen
using OrdinaryDiffEqVerner: Vern9

x, mu = MX.sym("x", 4), MX.sym("mu")
r3 = (x[1]^2 + x[2]^2)^1.5
ode = vertcat(x[3], x[4], -mu * x[1] / r3, -mu * x[2] / r3)
model = Dict("x" => x, "p" => mu, "ode" => ode)
nothing # hide
```

The dictionary has the state `"x"` and its derivative `"ode"`, and optionally the
parameters `"p"`, the time `"t"` (a symbol that the right side uses) and the
quadratures `"quad"`. Without `"p"`, the function is `F(x0)`. A quadrature is an
expression that the solver integrates along the solution.

## Integrate between two fixed times

```@example ode
F = integrator("F", Vern9(), model, 0.0, 3.0; abstol = 1e-13, reltol = 1e-13)

x0, p = MX.sym("x0", 4), MX.sym("p")
f = CasADiCodegen.Function("f", [x0, p], [F(x0, p), jacobian(F(x0, p), x0)])
g, g! = build_function(f; expression = Val{false})
xf, stm = g([1.0, 0.0, 0.0, 1.0], [1.0])
xf
```

The keywords go to the solver. `stm` is the Jacobian of the final state by the
initial state.

## Choose the form of the times

| Call | Function | Result |
|---|---|---|
| `integrator(name, alg, dae, t0, tf)` | `F(x0, p)` | State at `tf` |
| `integrator(name, alg, dae, t0, times)` | `F(x0, p)` | Matrix with the state at each time in one column |
| `integrator(name, alg, dae)` | `G(x0, p, t0, tf)` | State at `tf`; CasADi also differentiates by the times |

With free times, the final time can be before the initial time or equal to it.
With `"quad"`, each function returns the quadratures as a second result.

```@example ode
G = integrator("G", Vern9(), model; abstol = 1e-13, reltol = 1e-13)
t0, tf = MX.sym("t0"), MX.sym("tf")
h = CasADiCodegen.Function("h", [x0, p, t0, tf], [jacobian(G(x0, p, t0, tf), tf)])
build_function(h; expression = Val{false})[1]([1.0, 0.0, 0.0, 1.0], [1.0], [0.0], [3.0])
```

The derivative by the final time is the right side at the final state.

## Get a gradient by many parameters

By default CasADi gets each derivative from forward sensitivities, which cost one
integration per initial state and per parameter. Pass `adjoint = true` to
`integrator` when you need the gradient of one number by many of them. A reverse
derivative, such as `gradient`, then integrates the adjoint equations backward,
once.

```@example ode
A = integrator("A", Vern9(), model, 0.0, 3.0; adjoint = true, abstol = 1e-13, reltol = 1e-13)
cost = CasADiCodegen.Function("cost", [x0, p], [gradient(CasADiCodegen.C.sumsqr(A(x0, p)), vertcat(x0, p))])
build_function(cost; expression = Val{false})[1]([1.0, 0.0, 0.0, 1.0], [1.0])
```

Forward derivatives and derivatives of higher order still use the sensitivities.
For the gradient of one number by 6 initial states and 36 parameters, measured once:

| Derivative | Time per call |
|---|---|
| Forward sensitivities | 90.7 µs |
| `adjoint = true` | 52.7 µs |

[How an integrator is differentiated](@ref) explains both methods.

## Shorten the compilation of the solver

Run `import SciMLBase` first. The solver compiles for each integrator, which takes about 3 s at the first call
of a function with the Jacobian of a new integrator. The keyword
`specialize = SciMLBase.AutoSpecialize` makes the solver call the right side
through a pointer with fixed argument types, as SciML does by default: the solver
then compiles once for all integrators
(2.0 s for the first and 0.3 s for each later one, measured on the two-body
problem) and the runs are about 10 percent slower (34.5 µs against 31 µs).

## Stop at an event

An integrator with free times can stop where a function of the state changes its
sign, and can apply a jump of the state there. See [Stop at an event](@ref events).

## Add algebraic states

A model with algebraic states has a diagonal mass matrix: the keyword `mass`
takes its diagonal, 0 for an algebraic state and 1 for the others, and
`"ode"` then holds the residual of the algebraic equation in the rows with the
mass 0. The algorithm must accept a mass matrix, as `Rodas5P()` of
OrdinaryDiffEqRosenbrock.jl does. The initial value of an algebraic state is a
guess, because the integrator first solves the algebraic equations by the Newton
method, and the result does not depend on that guess. Forward derivatives of any
order are supported. With `mass`, the times are `t0` and `tf`, fixed or free, and `adjoint = true` gives
adjoint equations with the same mass. A vector of times and an event function are
not supported.

```julia
using OrdinaryDiffEqRosenbrock: Rodas5P

y, k = MX.sym("y", 3), MX.sym("k")                       # y[3] is algebraic: y[3] = k y[1]
model = Dict("x" => y, "p" => k, "ode" => vertcat(-y[3], y[1], y[3] - k * y[1]))
stiff = integrator("stiff", Rodas5P(), model, 0.0, 1.0; mass = [1.0, 1.0, 0.0], abstol = 1e-11, reltol = 1e-11)
```

## Write the model to a file

`generate_julia` writes a function with an integrator to a module that makes the
solver again. That module loads CasADiCodegen.jl, SciMLBase.jl and the package of the
algorithm. The algorithm and the options of the solver must then be
values that a source file can hold: numbers, symbols and structures of them.

## Integrate many arcs

An arc is one integration between two times. `map` of CasADi applies a function to
each column of its arguments, so a map of an integrator gives the arcs of a multiple
shooting method. The example has 20 arcs of the integrator `F` above, with the
Jacobian of all final states by all initial states. Each arc is integrated once, and
the time per arc is that of a separate function for one arc (28 µs against 29 µs,
measured once).

```julia
X = MX.sym("X", 4, 20)
ends = CasADiCodegen.C.map(F, 20)(X, CasADiCodegen.C.repmat(p, 1, 20))
f = CasADiCodegen.Function("shoot", [X, p], [ends, jacobian(ends, X)])
```
