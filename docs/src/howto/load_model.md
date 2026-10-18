# Load a model from another language

A model written with CasADi in Python, MATLAB or C++ becomes Julia code with no
translation by hand. Save the function there with the method `save` of CasADi:

```python
f.save("model.casadi")        # Python; in MATLAB the call is the same
```

Load the file in Julia with `CasADiCodegen.Function.load`. `build_function` and
`generate_julia` take the result as any other function.

```@example load
using CasADiCodegen

x = SX.sym("x", 2)                                    # stands for the model of the other language
CasADiCodegen.Function("f", [x], [x[1] * sin(x[2])]).save(joinpath(tempdir(), "model.casadi"))

f = CasADiCodegen.Function.load(joinpath(tempdir(), "model.casadi"))
g, g! = build_function(f; expression = Val{false})
g([2.0, 0.5])
```

The file must come from CasADi 3.8.1 or older, because CasADi reads the files of
older versions only. A model that holds a solver of CasADi (`cvodes`, `nlpsol`, ...)
also needs [Replace the solvers of CasADi](@ref).
