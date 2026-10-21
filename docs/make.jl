using Documenter
using CasADiCodegen
import SciMLBase, ChainRulesCore, SparseArrays

extension(name) = Base.get_extension(CasADiCodegen, name)

makedocs(;
    sitename = "CasADiCodegen.jl",
    modules = [CasADiCodegen, CasADiCodegen.Codegen, extension(:CasADiCodegenSciMLBaseExt), extension(:CasADiCodegenChainRulesCoreExt), extension(:CasADiCodegenSparseArraysExt)],
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://EllissoideRotondo.github.io/CasADiCodegen.jl",
        edit_link = "main",
    ),
    # The front end exports names with docstrings of its own, which are not part of this manual.
    checkdocs = :none,
    pages = [
        "Home" => "index.md",
        "Getting started" => "getting_started.md",
        "Models" => [
            "howto/load_model.md",
            "howto/traced_models.md",
            "howto/callbacks.md",
            "howto/integrators.md",
            "howto/events.md",
            "howto/rootfinders.md",
        ],
        "Solvers and SciML" => [
            "howto/casadi_solvers.md",
            "howto/sciml_functions.md",
            "howto/autodiff_rules.md",
        ],
        "Large models and debugging" => [
            "howto/large_functions.md",
            "howto/inspect.md",
        ],
        "Concepts" => [
            "explanation/matrix_code.md",
            "explanation/integrator_derivatives.md",
            "explanation/performance.md",
            "explanation/scope.md",
        ],
        "API reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/EllissoideRotondo/CasADiCodegen.jl",
    devbranch = "main",
)
