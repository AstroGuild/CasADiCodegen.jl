using Documenter
using CasADiCodegen
import SciMLBase, ChainRulesCore, SparseArrays

extension(name) = Base.get_extension(CasADiCodegen, name)

makedocs(;
    sitename = "CasADiCodegen.jl",
    modules = [CasADiCodegen, CasADiCodegen.Codegen, extension(:CasADiCodegenSciMLBaseExt), extension(:CasADiCodegenChainRulesCoreExt), extension(:CasADiCodegenSparseArraysExt)],
    format = Documenter.HTML(; prettyurls = false, edit_link = nothing, repolink = nothing),
    remotes = nothing,
    # The front end exports names with docstrings of its own, which are not part of this manual.
    checkdocs = :none,
    pages = [
        "Home" => "index.md",
        "Getting started" => "tutorial.md",
        "How-to guides" => [
            "howto/load_model.md",
            "howto/callbacks.md",
            "howto/integrators.md",
            "howto/events.md",
            "howto/rootfinders.md",
            "howto/casadi_solvers.md",
            "howto/sciml_functions.md",
            "howto/large_functions.md",
            "howto/autodiff_rules.md",
            "howto/inspect.md",
        ],
        "Explanation" => [
            "explanation/matrix_code.md",
            "explanation/integrator_derivatives.md",
            "explanation/scope.md",
        ],
        "API reference" => "api.md",
        "Developer notes" => "developer.md",
    ],
)
