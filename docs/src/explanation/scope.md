# Scope and differences from CasADi

## What is supported

| Item | State |
|---|---|
| Scalar (SX) functions | Each scalar operation of CasADi 3.8.1, listed below |
| Matrix (MX) functions, not expanded | Elementwise operations, slices, joins, splits, transpose, reshape, projection, assignment to nonzeros, nonzeros at indices that are values, the search of an interval in a grid, `monitor`, calls to SX and MX functions, `map`, `mapaccum` and `fold`, `if_else` and `conditional` with `short_circuit` |
| Functions and nodes of CasADi without instructions | Julia code for the interpolants `linear` and `bspline`, the B-spline node, `einstein`, `kron_contract`, `repsum`, `convexify`, `attachAssert`, `printme`, `dump`, `find`, `map` on threads, external functions (`Float64` only), the rootfinder `newton`, and the integrators `rk` and `collocation` with sensitivities of the first and the second order |
| Solver objects of CasADi | As SciML problems: `ODEProblem`, `NonlinearProblem` and `OptimizationProblem`. In generated code with `solvers = CasADiCodegen.Solvers(...)`: `cvodes`, `idas`, `kinsol`, `fast_newton` and the solvers of `nlpsol` (`Float64` only), with forward and reverse derivatives, the integrators with event functions (`Float64` only, forward derivatives), and the solvers of `conic` for quadratic problems |
| Linear algebra, not expanded | Matrix product, inner product, bilinear form, rank one update, Frobenius, 1 and infinity norms, smallest and largest element, Kronecker product, `logsumexp`, determinant, inverse, linear solve |
| Julia functions | `callback(f, name, sizes_in, sizes_out; jacobian)`, with derivatives of any order from Julia functions or from a backend |
| Functions of SciML problems | `ODEFunction`, `NonlinearFunction` and `OptimizationFunction` from CasADi functions, with generated derivatives; dense matrices; no Hessian of the Lagrangian, which the solvers make from the Hessians of the constraints |
| Roots of equations | `rootfinder(name, alg, f)`; dense unknowns and arguments, derivatives of any order |
| Ordinary differential equations | `integrator(name, alg, dae, t0, tf)`, with free times `integrator(name, alg, dae)`, and with a vector of times for `tf`; quadratures, forward sensitivities, adjoint sensitivities with `adjoint = true`, and with free times one or more events, each with a transition of the state; algebraic states with `mass`, with forward and adjoint sensitivities; no vector of times or event |
| Rules for automatic differentiation | `CasADiCodegen.differentiable(f)`, with a forward and a reverse rule for ChainRulesCore.jl |
| Julia functions on symbols | Methods that the front end leaves undefined: `inv` as the matrix inverse, `min`, `max`, `ifelse`, `atan(y, x)`, `hypot`, `rem`, `!=`, `&`, `LinearAlgebra.dot`, `LinearAlgebra.norm`, `SpecialFunctions.erf` |
| Forms of a generated function | Out of place and in place on `Array`, `SArray` and `MArray` in matrix shape; in place on `SparseMatrixCSC`; in place on vectors of nonzeros with `nonzeros = true` |
| Number types | `Float64`, `Float32` and ForwardDiff dual numbers; any real type with `nanmath = false` |

The scalar operations are:

| Kind | Operations |
|---|---|
| Arithmetic | `+`, `-`, `*`, `/`, negation, reciprocal, square, twice, `^` with any exponent, `sqrt`, `abs`, `sign`, `copysign`, `hypot` |
| Exponential | `exp`, `log`, `expm1`, `log1p` |
| Trigonometric | `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh` |
| Rounding | `floor`, `ceil`, `fmod`, `remainder` |
| Comparison and logic | `<`, `<=`, `==`, `!=`, `not`, `and`, `or`, `if_else_zero`, `fmin`, `fmax` |
| Special | `erf`, `erfinv`, `printme` |

## What is refused

Generated code never calls CasADi. A function whose method is not in this package
is thus refused when the code is built, and the message names the function and
says what the user can do, as the table shows. 
| Function of CasADi in the graph | What the user can do |
|---|---|
| Integrator `cvodes` or `idas` | Give a solver of the SciML ecosystem with the option `solvers` (see [Replace the solvers of CasADi](@ref)) |
| Rootfinder `kinsol` or `fast_newton` | Give a solver with the option `solvers` |
| Solver of `nlpsol` | Give a solver with the option `solvers` |
| Integrator `rk` or `collocation` with an event function | Give a solver with an override, `Solvers(overrides = ...)` |
| Forward directions of an integrator of CasADi with an event function and algebraic states | Nothing: they are not supported |
| Callback of a subtype of `CasadiCallback`, whose Julia object CasADi keeps to itself | Make it with `callback` and a Julia function |
| Solver of `conic` (quadratic problem) | Give a solver with the option `solvers`, field `optimization`; CasADi itself has no derivatives of such a solver |
| Solver of `conic` with cone constraints; other classes, such as a Functional Mock-up Unit (FMU) | Nothing: they are not supported |
| Matrix 2-norm without expansion | Nothing: CasADi itself cannot evaluate it |

## Differences from CasADi

### Numbers in a Dict of options

!!! warning "Integer options before version 0.26.0"
    The Julia front end of CasADi 3.8.1 (CasADiSWIG_jll) gives an integer, or a
    `Float64` with a whole value, in a Dict of options to CasADi as `true`, that is
    1. Before version 0.26.0, CasADiCodegen.jl passed these values unchanged, so
    `Dict("number_of_finite_elements" => 7)` made an integrator with 1 step, and
    `"max_iter" => 50` allowed 1 iteration, in a nested Dict too. CasADi gave no
    error, because it accepts `true` for an integer or a real option. The values 0
    and 1 were right by chance; any other whole number, negative too, was 1. A model
    with such an option gives other numbers from version 0.26.0 on, and you should
    compute again any result that came from it. Your code needs no change.

The cause is in the code that SWIG generates for Julia: it converts each value of a
Dict of options to a `GenericType` of CasADi and tries the type `bool` first, which
accepts any `Int64` and any `Float64` that is a whole number. A vector of such numbers
becomes a vector of `bool`, which CasADi refuses with the error "type mismatch", as for
the options `constraints` and `u_scale` of `kinsol`; a vector thus gave an error and no
wrong result. CasADiNative.jl passes the Dict to this code as it is. When
CasADiCodegen.jl is loaded, it adds to each function of the generated module
`CasADiNative.C` that takes options a method for an `AbstractDict`, which converts the
Dict and then calls the method of the front end; an integer thus reaches CasADi as an
integer and any other real number as a double, also in a vector and in a nested Dict.
These methods change the behaviour of CasADiNative.jl in the whole Julia session, as
do the method of `callback` that takes a Julia function and the methods of
`integrator` and `rootfinder` that take an algorithm of SciML.

Two cases keep the defect: a value in a `Vector{Any}` or in another container that is
not a Dict, and CasADiNative.jl used without CasADiCodegen.jl loaded. In the
first case, give a vector with a concrete element type, such as `[1, 2]` or
`Float64[1, 2]`, and give nested options as a Dict. The function
`change_option(f, name, value)` is not affected: it takes a `GenericType` only, and the
front end has no way to make one from a number.

### Other differences

Five other behaviours differ from what a user of CasADi or of Julia can expect.

- The `newton` rootfinder does not read the option `constraints`, because the Newton
  method of CasADi does not use it.
- An operation that leaves its domain gives `NaN`, through NaNMath.jl, as in CasADi;
  `nanmath = false` selects the functions of Base, which throw. `erfinv` is the
  accurate `SpecialFunctions.erfinv`, where that of CasADi has a relative error up
  to 1e-4.
- Determinant, inverse and linear solve use a dense LU factorization, where CasADi
  uses a sparse QR factorization, so the results agree to rounding error only, and a
  singular matrix gives `Inf` or `NaN` and no error. A solve with a sparse matrix of
  8 rows or more uses the sparse QR factorization of CasADi when its factors have
  fewer nonzeros than half of the full matrix; for a tridiagonal matrix, measured once:

  | Rows | Sparse QR | Dense LU | CasADi virtual machine |
  |---|---|---|---|
  | 50 | 1.9 µs | 10.3 µs | 6.6 µs |
  | 200 | 7.8 µs | 143.7 µs | 12.3 µs |
- CasADi 3.8.1 evaluates a sum to the nonzeros at a fixed slice plus indices that are
  values wrongly, with values from other memory; this node is the reverse derivative
  of a read such as `get_nz(v, false, Slice(1, 5, 2), i)`. The generated code gives
  the correct sum, so it differs from the CasADi virtual machine there.
- `inv(A)` is the matrix inverse for SX and for MX, as in Julia, and `inv(A, "qr")`
  names the linear solver of an MX graph. The function `CasADiNative.C.inv(A)` of the
  front end of CasADi 3.8.1 is the reciprocal of each element for an MX matrix.
