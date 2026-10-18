# Call a Julia function from the model

[`CasADiNative.callback`](@ref) makes a plain Julia function a CasADi function that a matrix (MX)
graph can call. Use it when a model reads an ephemeris, a table or any other code
that CasADi cannot see. The generated code calls the Julia function directly.

```@example cb
using CasADiNative, CasADiCodegen

drag(v) = -0.5 * sqrt(v[1]^2 + v[2]^2) .* v                  # any Julia code
drag_jacobian(v) = (n = sqrt(v[1]^2 + v[2]^2); -0.5 * (n * [1 0; 0 1] + v * v' / n))
force = callback(drag, "drag", (2,), (2,); jacobian = drag_jacobian)

v = MX.sym("v", 2)
f = CasADiNative.Function("f", [v], [force(2v), jacobian(force(2v), v)])
g, g! = build_function(f; expression = Val{false})
g([3.0, 4.0])[2]
```

The two tuples hold one size per argument and one per result. A size is an integer
for a vector, or a tuple `(rows, columns)` for a matrix. The Julia function receives
one array per argument, here the vector `v`, and returns one array per result.

## Give the derivatives

The keyword `jacobian` tells CasADi how to differentiate the function:

| `jacobian` | Derivatives | Notes |
|---|---|---|
| A Julia function | First order | It takes the arguments of the function. It returns the Jacobian matrix (rows for the elements of the result, columns for those of the argument), or a tuple with one matrix per pair of result and argument |
| A tuple of Julia functions | One order per function | Each function returns the Jacobian of the one before it. A matrix result counts as the vector of its elements in column-major order |
| An ADTypes.jl backend | Any order | It runs through DifferentiationInterface.jl, which is slower than functions |

## Example: an ephemeris in a force model

A function can return a static array, so that the call allocates no memory. The
example below is a sketch, not a complete program: `t0`, `t1` and the gravity
constants are yours, and Allspice.jl is a package that reads ephemeris files. The
model is a body that the Moon perturbs, with the position of the Moon and
its time derivatives from an ephemeris table of Allspice.jl. `table_jet(tab, t, Val(k))`
of that package returns the position and its first `k` time derivatives:

```julia
using CasADiNative, CasADiCodegen, Allspice, LinearAlgebra

tab = ephemeris_table("MOON", t0, t1, "J2000", "NONE", "EARTH")
order(k) = let v = Val(k); t -> table_jet(tab, t[1], v)[k+1]; end       # derivative k of the position
moon = callback(order(0), "moon", (1,), (3,); jacobian = (order(1), order(2)))

x, t = MX.sym("x", 6), MX.sym("t")
r, s = x[1:3], moon(t)
a = -GM_EARTH * r / norm(r)^3 + GM_MOON * ((s - r) / norm(s - r)^3 - s / norm(s)^3)
z = vertcat(x, t)
f = CasADiNative.Function("f", [x, t], [vertcat(x[4:6], a), jacobian(vertcat(x[4:6], a), z)])
g, g! = build_function(f; expression = Val{false})
```

For this model with a second such term for the Sun, measured once on Julia 1.13 against the
same model in plain Julia with ForwardDiff.jl, to which the results agree to rounding:

| Outputs | In place | Memory per call |
|---|---|---|
| Right side | 0.09 µs | 0 B |
| Right side and Jacobians by state and time | 0.19 µs | 0 B |
| Right side, Jacobian and second derivatives by state and time | 0.63 µs | 0 B |
| Right side, plain Julia | 0.12 µs | 0 B |

## How the code reaches the function

CasADi cannot expand a call to a Julia function, but the package expands the
operations before, between and after the calls, so that the generated code is
scalar code in one function that passes static arrays to the Julia functions and
reads their results as static arrays or as ordinary arrays. A call whose results
no output needs is left out. The code stays matrix code with `expand = false`,
when it is so large that it must be split (see [Large functions and the cache on disk](@ref)), and when a
call is inside a called function that CasADi does not inline. Four rules follow
from how the code reaches the function.

- A function that `build_function` makes for the session holds the Julia function itself, so a closure works,
  as `order(k)` above, and the data that it captures stay alive with it.
- `generate_julia` writes each call by the full name of the function and adds an
  `import` of its package to the module. It therefore needs named functions of a
  module, whose data are constants of that module, it rejects closures and a
  Jacobian from a backend, and the package must be in the environment that loads
  the file.
- The functions must accept the number type of the call, for example dual numbers
  when ForwardDiff.jl differentiates the generated code.
- The package keeps each Julia function that `callback`, `integrator` or `rootfinder`
  wraps in a table for the life of the session, because CasADi can call it at any
  later time; a program that makes such functions in a loop therefore uses more
  memory at each pass, and must make them once and reuse them.
