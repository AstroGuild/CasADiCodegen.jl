# CasADiCodegen.jl

Use the project skills whenever Julia APIs, documentation or tests change:

- `julia-doc-quality`: README, docstrings, Documenter manual (adds to the global
  skills `julia-docstrings`, `julia-manual` and `julia-readme`).
- `julia-test-quality`: tests (adds to the global skill `julia-tests`).
- The global skill `julia-doc-reader-review`: review of documentation after a change,
  with the global agent `julia-doc-reader`.

Commands: tests `julia -e 'using Pkg; Pkg.test("CasADiCodegen")'` (one group with
`test_args=["mx"]`); manual `julia --project=docs docs/make.jl`.

The library stays application-agnostic. Nothing is submitted upstream to CasADi or
Yggdrasil.
