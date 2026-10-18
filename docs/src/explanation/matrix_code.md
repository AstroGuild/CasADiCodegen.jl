# Matrix code and functions without instructions

## Expanded code and matrix code

By default a matrix (MX) function is expanded to scalar operations, which gives the
fastest code for a model of moderate size but repeats the body of a called function
at each call, so a model with many calls of a large function compiles slowly and can
run slower (see [Cost of the two kinds of code](@ref)). With
`expand = false`, or when CasADi cannot expand the function, the generated code
keeps the matrix operations, and each called function becomes one Julia function
that is compiled once.

`if_else(c, a, b, true)` and `conditional(k, cases, default, true)` of CasADi make a
switch between functions. Expanded code computes each branch and selects one value,
as CasADi does when it expands; code that keeps the matrix operations runs only the
branch that is selected, which matters when a branch is expensive, as a call of a
Julia function or of an integrator is, and such a branch keeps the code unexpanded.

```julia
g, g! = build_function(f; expression = Val{false}, expand = false)   # f is an MX function
```

Code that keeps the matrix operations also has the operations that CasADi cannot
expand to scalar code. An index that is a value of the model, as in `v[i]` with a
symbolic `i`, and the search of an interval in a grid, which a linear interpolant
with the option `inline` uses, become ordinary Julia code; `monitor` prints its
operand with its text at each call.

## Functions and nodes of CasADi without instructions

Some functions and nodes of CasADi have no list of instructions, and CasADi does not
give their data through its interface. The package reads that data from two texts
that CasADi can write for any function: the C code that it generates, which holds
each table and each index list, and the text that `serialize` gives with the names
of the fields, which holds the options of a solver. From that data the package emits Julia code
that does not call CasADi and that takes dual numbers. When it builds the code, the
package evaluates it at test points and compares the values with those of CasADi;
a difference is an error at build time.

| Function or node of CasADi | Julia code |
|---|---|
| Interpolant, `linear` or `bspline`, with fixed values or with the values as an argument | The search in the grid and the B-spline recursion of CasADi, with the lookup modes `linear`, `exact` and `binary` |
| B-spline node, tensor product (`einstein`), contracted Kronecker product, sum of repeated blocks, `find` (the index of the first nonzero element) | The loops of CasADi over tables that are read from its C code |
| `convexify`, which makes a symmetric matrix positive definite | The routines of CasADi 3.8.1, statement by statement, for the three strategies |
| `attachAssert`, `monitor`, `printme`, `dump`, `lift` | The check, the print or the file of CasADi; the value passes |
| `map` on threads or with OpenMP | A loop |
| External function from a compiled library | A direct call of the library, with `Float64` only |
| Rootfinder `newton` | The iteration of CasADi 3.8.1 with its line search and its options |
| Integrators `rk` and `collocation`, with forward and adjoint sensitivities and with derivatives of the second order | The loop of steps of CasADi, as a loop over the step function of CasADi; a collocation step is a Newton rootfinder |

The times below are for one call of the generated code with `Float64`, and for the
same function evaluated by CasADi through the front end, measured once. The
interpolants have 9 points and return the value with its derivative, the
integrators have 2 states and 20 steps and return the final state with its Jacobian,
and the rootfinder has 2 unknowns and returns the root with its Jacobian by 3
parameters.

| Function | Generated code | Memory per call | CasADi |
|---|---|---|---|
| Interpolant `linear` | 0.05 µs | 0 B | 4.7 µs |
| Interpolant `bspline` | 0.11 µs | 0 B | 4.9 µs |
| `convexify` of a 4 by 4 matrix, `eigen-clip` | 0.52 µs | 0 B | 4.3 µs |
| Rootfinder `newton` | 3.6 µs | 304 B | 49 µs |
| Integrator `rk` | 6.7 µs | 0 B | 262 µs |
| Integrator `collocation` | 112 µs | 11 kB | 1570 µs |

## Cost of the two kinds of code

For a model that calls one scalar function of 710 instructions 20 times in a chain
and returns the result with its Jacobian, measured once:

| Form | Build | First call | Later calls | Memory per call |
|---|---|---|---|---|
| `expand = true` | 4.8 s | 86 s | 183 µs | 85 kB |
| `expand = false` | 0.3 s | 13 s | 134 µs | 16 kB |
| CasADi virtual machine | | | 950 µs | |
