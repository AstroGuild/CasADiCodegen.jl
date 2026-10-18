# Generated code kept on disk. A runtime generated function is compiled again
# in each Julia session; a package is compiled once, and Julia stores its
# machine code. So the cache writes the module of `generate_julia` into a
# small package with `precompile` statements and loads that package.

const CACHE_NAMESPACE = Base.UUID("2e42ddf9-3b2b-405e-8fd5-d52a4b84c49f")     # the UUID of this package
const CACHE_LOCK = ReentrantLock()

cache_directory(cache::AbstractString) = String(cache)
cache_directory(::Bool) = joinpath(first(DEPOT_PATH), "scratchspaces", string(CACHE_NAMESPACE), "generated")

"""
    dependency(name) -> Base.PkgId

Return the identity of the package `name` that a generated module imports. The package is
a dependency of this package, or a package that is loaded, as the package of a Julia
function in the graph is. SparseArrays.jl is accepted by its known identity, and must then
be in the environment.
"""
function dependency(name::Symbol)
    id = Base.identify_package(Package, String(name))
    id === nothing || return id
    name === :SparseArrays && return Base.PkgId(Base.UUID("2f01184e-e22b-5df5-ae63-d93ebab69eaf"), "SparseArrays")
    loaded = [id for id in keys(Base.loaded_modules) if id.name == String(name) && id.uuid !== nothing]
    @requires !isempty(loaded) "the cache cannot find the package $name that the generated code imports"
    first(loaded)
end

"The type of a dense array with the shape of `sp`, as source text: ordinary or static."
function array_type(sp, static::Bool)
    rows, columns = C.size1(sp), C.size2(sp)
    static && return columns == 1 ? "StaticArrays.SVector{$rows,Float64}" : "StaticArrays.SMatrix{$rows,$columns,Float64,$(rows * columns)}"
    columns == 1 ? "Vector{Float64}" : "Matrix{Float64}"
end

tuple_type(types) = "Tuple{" * join(types, ",") * "}"

"""
    precompile_statements(alg, name, nonzeros, force_SA) -> Vector{String}

Return the `precompile` statements of a cached package, for `Float64`. With `nonzeros` they
are for the function on nonzeros. Otherwise they are for the in-place function on ordinary
arrays and for the out-of-place function on ordinary arrays, or on static arrays with
`force_SA`.
"""
function precompile_statements(alg, name::Symbol, nonzeros::Bool, force_SA::Bool)
    if nonzeros
        arguments = tuple_type(fill("Vector{Float64}", length(alg.nnz_in)))
        results = ("Vector{Vector{Float64}}", tuple_type(fill("Vector{Float64}", length(alg.nnz_out))))
        return ["precompile(Generated.$(core_name(name)), ($result, $arguments))" for result in results]
    end
    inputs, outputs = [array_type(sp, false) for sp in alg.sparsity_in], [array_type(sp, false) for sp in alg.sparsity_out]
    given = force_SA ? [array_type(sp, true) for sp in alg.sparsity_in] : inputs
    ["precompile(Generated.$name, ($(tuple_type(outputs)), $(tuple_type(inputs))))",
     "precompile(Generated.$(outofplace_name(name)), ($(join(given, ", ")),))"]
end

"""
    cached_module(generated, statements, imports, directory) -> Module

Write, compile and load the package that holds the source text `generated` (a module with
the name `Generated`) and the `precompile` statements. Return the module of the package.

The name of the package comes from its content, so equal content is written and compiled
once, and the package is loaded once in a session. The packages of `imports` must be found
by `dependency`.
"""
function cached_module(generated::String, statements, imports, directory::String)
    wrapper = join(["import StaticArrays", "include(\"generated.jl\")", statements...], "\n")
    name = "CasADiCodegenCache_" * string(hash(generated, hash(wrapper)), base = 16, pad = 16)
    id = Base.PkgId(Base.uuid5(CACHE_NAMESPACE, name), name)
    dependencies = sort!(unique!([dependency(dep) for dep in (:StaticArrays, imports...)]); by = dep -> dep.name)
    loaded = lock(CACHE_LOCK) do
        Base.root_module_exists(id) && return Base.root_module(id)
        package = joinpath(directory, name)
        if !isdir(package)
            # Another process can write the same package; the first complete one stays.
            staging = mktempdir(mkpath(directory))
            mkdir(joinpath(staging, "src"))
            write(joinpath(staging, "src", "generated.jl"), generated)
            write(joinpath(staging, "src", name * ".jl"), "module $name\n$wrapper\nend\n")
            write(joinpath(staging, "Project.toml"), "name = \"$name\"\nuuid = \"$(id.uuid)\"\nversion = \"0.1.0\"\n\n[deps]\n" *
                  join(("$(dep.name) = \"$(dep.uuid)\"\n" for dep in dependencies)))
            try mv(staging, package) catch end
            @ensures isdir(package) "the cache cannot write the package $package"
        end
        push!(LOAD_PATH, package)
        try
            Base.require(id)
        finally
            deleteat!(LOAD_PATH, findlast(==(package), LOAD_PATH))
        end
    end
    @ensures Base.invokelatest(isdefined, loaded, :Generated) "the cached package must hold the generated module"
    loaded
end

"""
    cached_functions(f, directory; nonzeros, force_SA, name, options...) -> functions

Return the result of `build_function` with `expression = Val{false}`, as the functions of
a cached package in `directory`. `options` are those of `generate_julia`, whose limits
hold. Each Julia function in the graph must be a named function of a package, not of `Main`.
"""
function cached_functions(f, directory::String; nonzeros::Bool, force_SA::Bool, name::Symbol, expand::Bool,
                          solvers::Union{Nothing,Solvers} = nothing, options...)
    alg = algorithm(f; expand, solvers)
    seen = Set{Symbol}()
    generated = sprint(io -> generate_julia(alg, io; module_name = :Generated, force_SA, name, seen, options...))
    @requires !(:Main in seen) "the cache needs each Julia function in the graph to belong to a package, not to Main"
    imports = sort!(collect(setdiff(seen, (:Base, :Core))))
    statements = precompile_statements(alg, name, nonzeros, force_SA)
    # The solvers of integrators compile with the package.
    occursin("\nconst OBJECTS = ", generated) && pushfirst!(statements, "foreach(Generated.CasADiCodegen.Codegen.warm, Generated.OBJECTS)")
    loaded = cached_module(generated, statements, imports, directory)
    code = Base.invokelatest(getfield, loaded, :Generated)
    get(symbol) = Base.invokelatest(getfield, code, symbol)
    nonzeros ? get(core_name(name)) : (get(outofplace_name(name)), get(name))
end
