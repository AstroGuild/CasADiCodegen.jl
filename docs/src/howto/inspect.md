# Inspect a model

When a generated function is slow, or returns a NaN, two functions of the package
look into the model: one counts its operations, and the other finds the first NaN.
They are not exported, so their names need the prefix `CasADiCodegen.`.

## Count the operations

[`CasADiCodegen.instruction_histogram`](@ref) gives the operations of the code that
`build_function` emits, each with its number of instructions, and thus shows what a
slow function spends its time on. Here we count the operations of a small function:

```@example inspect
using CasADiCodegen

x = SX.sym("x", 2)
f = CasADiCodegen.Function("f", [x], [sqrt(x[1] - x[2]) * sin(x[1]) + x[2]^2])
CasADiCodegen.instruction_histogram(f)
```

## Find the source of a NaN

[`CasADiCodegen.nan_trace`](@ref) runs the scalar code of a function on numbers. It returns
the first instruction that makes a NaN from operands that have none, or the first
NaN among the arguments, or `nothing`. With `x = [2, 5]`, the square root of
`x[1] - x[2]` is that of a negative number:

```@example inspect
CasADiCodegen.nan_trace(f, [2.0, 5.0])
```
