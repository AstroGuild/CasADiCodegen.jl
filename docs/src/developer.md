# Developer notes

## Tests

```sh
julia -e 'using Pkg; Pkg.test("CasADiCodegen")'                              # all groups
julia -e 'using Pkg; Pkg.test("CasADiCodegen"; test_args = ["mx", "root"])'  # two groups
```

Each group is a file `test/test_<group>.jl` that runs in its own Julia process, and
several groups run at the same time, because most of the time is compilation that
the groups do not share.

| Environment variable | Effect |
|---|---|
| `CASADI_TEST_JOBS` | Number of groups that run at the same time (default 6, or half of the processor threads) |
| `CASADI_TEST_VERBOSE` | Each group prints the time of each of its test sets |

On Julia 1.12 add `julia_args = ["--check-bounds=auto"]` to `Pkg.test`: with the bounds
checks that `Pkg.test` sets there, the group `nodes` takes about 11 minutes instead of one
(see [Keep bounds checks off in tests](@ref)).

The oracles are CasADi itself, exact solutions and a reference interpreter in
`test/interpreter.jl`. The files in `test/features` state the user-visible
behaviour in Gherkin.

## Manual

Build it with `julia --project=docs docs/make.jl`, after one
`Pkg.instantiate()` in that project. The examples of the manual run during the build, so a build without warnings shows
that they still work. The result is in `docs/build`.
