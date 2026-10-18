# Use the generated derivatives from an AD package

[`CasADiCodegen.differentiable`](@ref) makes a CasADi function a Julia function with rules for
ChainRulesCore.jl, so that a package for automatic differentiation that reads those
rules, such as Zygote.jl, takes the derivatives from code that CasADi generates and
does not trace the function. The result takes one array per input and returns one
array per output, as the out-of-place function of `build_function`, to which the
options go. The rules load with ChainRulesCore.jl, and the code of the forward rule
and of the reverse rule is made at the first use of each one.

```julia
import ChainRulesCore, Zygote

d = CasADiCodegen.differentiable(f)                       # f is a CasADi function (x, p) -> y
dx, dp = Zygote.gradient((x, p) -> sum(abs2, d(x, p)), [1.0, 2.0], [0.5])
```
