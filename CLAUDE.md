# CasADiCodegen.jl

Use the project skills whenever Julia APIs, documentation or tests change:

- `julia-doc-quality`: README, docstrings, Documenter manual.
- `julia-test-quality`: tests.
- `julia-doc-review`: review of documentation after a change.

Commands: tests `julia -e 'using Pkg; Pkg.test("CasADiCodegen")'` (one group with
`test_args=["mx"]`); manual `julia --project=docs docs/make.jl`.

The library stays application-agnostic. Nothing is submitted upstream to CasADi or
Yggdrasil.
