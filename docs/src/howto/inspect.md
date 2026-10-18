# Inspect a model

Two functions help to look into a model. They are not exported, so their names need
the prefix `CasADiCodegen.`.

## Count the operations

[`CasADiCodegen.instruction_histogram`](@ref) gives the operations of the code that
`build_function` emits, each with its number of instructions. It shows what a slow
function spends its time on.

```@example inspect
using CasADiCodegen

x = SX.sym("x", 2)
f = CasADiCodegen.Function("f", [x], [sqrt(x[1] - x[2]) * sin(x[1]) + x[2]^2])
CasADiCodegen.instruction_histogram(f)
```

## Find the source of a NaN

[`CasADiCodegen.nan_trace`](@ref) runs the scalar code of a function on numbers. It returns
the first instruction that makes a NaN from operands that have none, or the first
NaN among the arguments, or `nothing`.

```@example inspect
CasADiCodegen.nan_trace(f, [2.0, 5.0])
```
