# Large functions and the cache on disk

## Split a large function

Julia compiles one large function slowly, because the time grows faster than the
number of instructions, so above a limit the code is split into sub-functions that
share one work vector, which holds the intermediate values. The work vector belongs
to the Julia task, so a call does not allocate it, and each form of the generated
function (see [Choose a form](@ref)) calls the same sub-functions. Two keywords control
the split, and each has a default that you can replace:

| Keyword | Meaning | Default |
|---|---|---|
| `split_above` | A function with more instructions is split | 50,000 for scalar code; 1,000 operations for matrix code |
| `chunk_size` | Largest number of instructions in one sub-function | 1,000 |

When only `chunk_size` is given, each function with more instructions than
`chunk_size` is split; `split_above = typemax(Int)` keeps any function in one piece.
The defaults come from the time of the first call, which is mostly compilation, and
from the time of the later calls, measured once on Julia 1.13 for the function on
nonzeros of two models with their dense Jacobians. The chain of maps is a function
that applies a `map` of CasADi to the result of the one before it; the gravity model
is the acceleration of 40 bodies that attract each other.

| Model | Instructions | Sub-function size | First call | Later calls |
|---|---|---|---|---|
| Chain of maps, 6 states | 67,236 | One function | 35 s | 21 µs |
| Chain of maps, 6 states | 67,236 | 500 | 14 s | 28 µs |
| Chain of maps, 6 states | 67,236 | 1,000 | 15 s | 27 µs |
| Chain of maps, 6 states | 67,236 | 5,000 | 26 s | 28 µs |
| Chain of maps, 6 states | 67,236 | 20,000 | 34 s | 25 µs |
| Gravity of 40 bodies | 102,946 | One function | 54 s | 70 µs |
| Gravity of 40 bodies | 102,946 | 500 | 39 s | 97 µs |
| Gravity of 40 bodies | 102,946 | 1,000 | 53 s | 96 µs |
| Gravity of 40 bodies | 102,946 | 5,000 | 63 s | 98 µs |
| Chain of maps, 6 states | 224,736 | One function | 339 s | 89 µs |
| Chain of maps, 6 states | 224,736 | 1,000 | 54 s | 105 µs |
| Chain of maps, 6 states | 224,736 | 5,000 | 92 s | 102 µs |
| Chain of maps, 6 states | 224,736 | 20,000 | 186 s | 102 µs |

The size of the sub-functions has almost no effect on the later calls, while the
first call becomes slower as the size grows, which is why the default size is small.
The split itself costs 15 to 35 percent of speed at any size. Whether it shortens the
first call depends on the model: near the default limit of 50,000 instructions (not
in the table) the first call of one function took 18 s for the chain and 14 s for the
gravity model, against 10 s and 22 s when split. Raise `split_above` when the speed of the later calls
matters more than the first call.

## Keep the compiled code between sessions

Julia compiles a runtime generated function again in each session. With
`cache = true`, `build_function` writes the generated module into a small package,
which Julia compiles once and whose machine code it stores, so that a later session
with the same model loads the functions and compiles nothing.

```julia
g, g! = build_function(f; expression = Val{false}, cache = true)
```

| Function | Without cache, each session | With cache, first session | With cache, later sessions |
|---|---|---|---|
| Chain of maps, 22,236 instructions | 6.2 s | 16.8 s | 1.1 s |
| Chain of maps, 67,236 instructions | 16.4 s | 19.7 s | 1.3 s |
| Two-body integrator, final state and its Jacobian | 4.1 s | 12.8 s | 2.0 s |

Each time is that of `build_function` together with the first call, and the speed of
the later calls does not change. The name of the package comes from the generated
code, so a changed model or other options give a new package, and an old one is
never used by mistake. The packages are in the directory `scratchspaces` of the first Julia depot (`~/.julia` by default),
or in the directory that `cache` names, and they can be deleted at any time. Four
rules apply.

- The package is compiled for `Float64` on ordinary arrays; `force_SA = true` compiles
  the out-of-place function for static arrays, and `nonzeros = true` the function on
  vectors of nonzeros. Other argument types compile at their first call, as before.
- The functions belong to a module that is loaded during the call of `build_function`.
  Code that runs already, such as the function that called `build_function`, must
  call them with `Base.invokelatest`; code that starts later calls them directly.
- A Julia function in the graph must be a named function of a package, as for
  `generate_julia`. An integrator or a rootfinder goes into the package with its
  algorithm and its options, and the package also holds the machine code of the
  solver for `Float64`, so that a later session does not compile the solver again.
- An input or an output with structural zeros makes the module import SparseArrays.jl,
  which must then be in the environment.

## Keep bounds checks off in tests

With `--check-bounds=yes`, Julia checks each array access of the generated code, so
the first call of a large function compiles much longer. `Pkg.test` sets this option on
Julia 1.12; on Julia 1.13 it keeps the setting of the session. For integrators of
CasADi with a fixed step, measured once:

| First call of | Julia 1.12 | Julia 1.12, `--check-bounds=yes` | Julia 1.13 | Julia 1.13, `--check-bounds=yes` |
|---|---|---|---|---|
| `rk` with Jacobians | 2.6 s | 23.7 s | 2.1 s | 8.3 s |
| `collocation` with Jacobians | 4.3 s | 41.5 s | 3.4 s | 11.5 s |
| `collocation` with derivatives of the second order | 16.6 s | 533 s | 14.6 s | 144 s |

On Julia 1.12, run such tests with `Pkg.test(...; julia_args = ["--check-bounds=auto"])`.
