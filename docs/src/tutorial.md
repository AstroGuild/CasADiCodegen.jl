# Getting started

This page builds a small model, generates Julia code for it, and shows the forms
that the generated code has.

## Write the model

`using CasADiCodegen` gives the official CasADi front end: the SWIG interface that ships
with CasADi 3.8.1, unchanged. Its calls are those of Python, and the
[CasADi documentation](https://web.casadi.org/docs/) describes them.

- The front end exports the common names: `SX`, `MX`, `DM`, `jacobian`, `gradient`,
  `hessian`, `vertcat`, `horzcat`, `substitute` and others.
- Each other function of CasADi is in the module `CasADiCodegen.C`, for example
  `CasADiCodegen.C.sumsqr` and `CasADiCodegen.C.nlpsol`.
- `CasADiCodegen.Function` needs its module name, because a bare `Function` is the abstract
  type of Julia.
- Elements have the indices of Julia: `x[1]` is the first one. Methods of CasADi that
  take an index of an input or an output keep the indices of CasADi, which start at 0.

```@example start
using CasADiCodegen

x = SX.sym("x", 3)
y = [sin(x[1]) * x[2]; x[3]^2 / (1 + x[1]^2)]
f = CasADiCodegen.Function("f", [x], [y, jacobian(y, x)])
nothing # hide
```

`f` has one input and two outputs: the value and its 2 by 3 Jacobian.

## Generate functions for this session

[`build_function`](@ref) returns a pair: an out-of-place and an in-place function.

```@example start
g, g! = build_function(f; expression = Val{false})
value, J = g([0.3, 1.7, -0.4])
J
```

The out-of-place function takes one array per input and returns one array per
output. A column is a `Vector`, any other shape is a `Matrix`, and a scalar is a
vector of one element. With one output the function returns the array itself.
`expression = Val{false}` asks for compiled functions; see [Choose a form](@ref).

The in-place function takes a tuple of outputs and a tuple of inputs:

```@example start
out = (zeros(2), zeros(2, 3))
g!(out, ([0.3, 1.7, -0.4],))
out[1]
```

## Avoid allocation with static arrays

A static array as the first argument gives static arrays back, with no allocation.
Add StaticArrays.jl to your environment first; CasADiCodegen.jl does not export it.

```@example start
using StaticArrays

value, J = g(SVector(0.3, 1.7, -0.4))
typeof(J)
```

`force_SA = true` makes the out-of-place function return static arrays for any
argument. The in-place function also accepts `MVector` and `MMatrix`.

## Fill a sparse Jacobian

Give the in-place function a `SparseMatrixCSC` with the pattern of the output.
`SparseMatrixCSC(sparsity)` makes one from a CasADi sparsity pattern. The function
then writes the stored values only, and rejects a matrix with another pattern.

```@example start
using SparseArrays

Js = SparseMatrixCSC(CasADiCodegen.C.sparsity_out(f, 1))   # pattern of the second output: CasADi counts from 0
g!((zeros(2), Js), ([0.3, 1.7, -0.4],))
Js
```

A structural zero is an element that the sparsity pattern leaves out. A structural
zero of an output is zero, and that of an input is not read.

## Write the code to a file

[`generate_julia`](@ref) writes one module. For a model as this one, the module does
not need CasADiCodegen.jl to run:

```@example start
path = joinpath(mktempdir(), "f.jl")
generate_julia(f, path; module_name = :F)
include(path)
F.f([0.3, 1.7, -0.4])[1]
```

`F.f!` is the in-place function, with the arguments of `g!` above:

```@example start
F.f!(out, ([0.3, 1.7, -0.4],))
out[2]
```

The module holds `F.f`, `F.f!` and `F.f_nonzeros!` (see [Choose a form](@ref)), and constants that describe the
function, such as `F.SPARSITY_OUT`. It imports StaticArraysCore.jl and, when the code uses it, NaNMath.jl. Both must
be in the environment that loads the file. A model with an integrator, a rootfinder
or an optimization solver gives a module that also loads CasADiCodegen.jl, SciMLBase.jl and
the package of the algorithm.

## Choose a form

| Call | Result | Needs CasADiCodegen.jl to run |
|---|---|---|
| `build_function(f)` | An `Expr` with the definitions, for `eval` or a macro | Yes |
| `build_function(f; expression = Val{false})` | Compiled functions for the current session | Yes |
| `build_function(f; expression = Val{false}, cache = true)` | The same, compiled once and loaded in later sessions | Yes |
| `generate_julia(f, path)` | A file with one module, for `include` or for a package | No, unless the model holds a SciML solver |

With `nonzeros = true`, `build_function` returns the single function
`(res, arg) -> res` on vectors of structural nonzeros, which is how CasADi itself
evaluates a function and which the other forms call.

## What it costs

An instruction is one scalar operation of the function, as CasADi counts them.
Scalar code allocates no memory in the in-place form and in the out-of-place form
with static arrays, whatever its size. The table has two models, each a function of
6 inputs with its 6 by 6 Jacobian, measured once on Julia 1.13:

| Instructions | Form | First call | Later calls | Memory per call |
|---|---|---|---|---|
| 5,361 | Out of place, static arrays | 0.62 s | 1.1 µs | 0 B |
| 5,361 | In place, arrays | 1.04 s | 1.2 µs | 0 B |
| 5,361 | Out of place, arrays | 0.68 s | 1.2 µs | 576 B |
| 18,861 | Out of place, static arrays | 3.69 s | 3.8 µs | 0 B |
| 18,861 | In place, arrays | 6.24 s | 3.9 µs | 0 B |
| 18,861 | Out of place, arrays | 3.82 s | 4.1 µs | 576 B |

The first call is mostly compilation. For a model above about 50,000 instructions,
see [Large functions and the cache on disk](@ref).

## Next steps

- A model that calls your own Julia code: [Call a Julia function from the model](@ref).
- A model with an integrator in it: [Integrate a differential equation](@ref).
- A model that exists already in Python, MATLAB or C++: [Load a model from another language](@ref).
- A matrix (MX) model with called functions: [Matrix code and functions without instructions](@ref).
