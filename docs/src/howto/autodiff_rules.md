# Use the generated derivatives from an AD package

A CasADi function inside Julia code that a package for automatic differentiation
(AD) differentiates, such as Zygote.jl, can give that package the derivatives that
CasADi computes. [`CasADiCodegen.differentiable`](@ref) makes the CasADi function a
Julia function with rules for ChainRulesCore.jl, so that the AD package takes the
derivatives from generated code and does not trace the function.

## Make a differentiable function

We make a CasADi function of two inputs, `x` and `p`, and call the result as the
out-of-place function of [`build_function`](@ref): it takes one array per input and
returns one array per output.

```@example rules
using CasADiCodegen

x, p = SX.sym("x", 2), SX.sym("p")
f = CasADiCodegen.Function("f", [x, p], [p * x[1] * sin(x[2])])

d = CasADiCodegen.differentiable(f)
d([2.0, pi / 2], [3.0])
```

`differentiable` needs only CasADiCodegen.jl. Its keywords go to `build_function`.

## Give the rules to an AD package

The forward rule and the reverse rule exist once ChainRulesCore.jl is loaded. We
call the reverse rule directly; its pullback returns the gradients by `x` and by `p`:

```@example rules
import ChainRulesCore

y, pullback = ChainRulesCore.rrule(d, [2.0, pi / 2], [3.0])
pullback([1.0])
```

An AD package that reads these rules calls them in the same way. With Zygote.jl in
the environment:

```julia
import Zygote

dx, dp = Zygote.gradient((x, p) -> sum(abs2, d(x, p)), [2.0, pi / 2], [3.0])
```

The package generates the code of the forward rule and of the reverse rule at the
first use of each one, so the first call of each rule is slower than the later calls.
