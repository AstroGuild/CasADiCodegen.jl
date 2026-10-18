# Functions on arrays in matrix shape, in place and out of place, next to the
# function on vectors of nonzeros; all of them run the same sub-functions.

"Linear indices, in the matrix shape, of the structural nonzeros of the pattern."
function nonzero_indices(sp::C.Sparsity)
    nrow, ncol, colptr, rowval = sparsity_tuple(sp)
    [(c - 1) * nrow + rowval[k] for c in 1:ncol for k in colptr[c]:colptr[c+1]-1]
end

dimensions(sp::C.Sparsity) = C.size2(sp) == 1 ? (C.size1(sp),) : (C.size1(sp), C.size2(sp))

is_dense(sp::C.Sparsity) = C.nnz(sp) == C.size1(sp) * C.size2(sp)

"""
    outofplace_name(name) -> Symbol

Return the name of the out-of-place function: `name` without its last character, which
must be `!`.
"""
function outofplace_name(name::Symbol)
    text = string(name)
    @requires endswith(text, "!") && Base.isidentifier(chop(text)) "the name of the in-place function must end with \"!\", got \"$name\""
    Symbol(chop(text))
end

"Statements that check the number of elements of each array of `res` (when `results`) and `arg`."
function shape_checks(alg; results::Bool)
    check(array, kind, i, name, sp) = :(length($array[$i]) == $(prod(dimensions(sp))) ||
        throw(ArgumentError(string($("$(alg.name): $kind $i ($name) needs $(prod(dimensions(sp))) elements, got "), length($array[$i])))))
    checks = Any[check(:arg, "argument", i, alg.names_in[i], sp) for (i, sp) in enumerate(alg.sparsity_in)]
    results && append!(checks, (check(:res, "result", j, alg.names_out[j], sp) for (j, sp) in enumerate(alg.sparsity_out)))
    checks
end

count_checks(alg) = Any[
    :(length(arg) == $(length(alg.sparsity_in)) || throw(ArgumentError(string($("$(alg.name): expected $(length(alg.sparsity_in)) arguments, got "), length(arg))))),
    :(length(res) == $(length(alg.sparsity_out)) || throw(ArgumentError(string($("$(alg.name): expected $(length(alg.sparsity_out)) results, got "), length(res))))),
]

zero_fills(alg) = Any[:(fill!(res[$j], 0)) for (j, sp) in enumerate(alg.sparsity_out) if !is_dense(sp)]

"""
    nonzero_call(alg, core, index, ref) -> Expr

Return the call of `core`, the function on vectors of nonzeros, with the structural
nonzeros of each array of `res` and `arg`. A dense array is passed itself. Another array
is passed as a view, or as the stored values of a sparse matrix with the sparsity pattern
of the function. `index(kind, k)` is the expression for the indices of the nonzeros of
input or output `k`.
"""
function nonzero_call(alg, core, index, ref)
    part(array, kind, k, sp) = is_dense(sp) ? :($array[$k]) : C.nnz(sp) == 0 ? :(()) :
                               :($(ref(:Helpers, :stored))($array[$k], $(index(kind, k))))
    arguments = [part(:arg, :in, i, sp) for (i, sp) in enumerate(alg.sparsity_in)]
    results = [part(:res, :out, j, sp) for (j, sp) in enumerate(alg.sparsity_out)]
    :($core($(Expr(:tuple, results...)), $(Expr(:tuple, arguments...))))
end

"Expressions that read and write a nonzero of scalar code at its place in the arrays in matrix shape."
function matrix_access(alg)
    index_in, index_out = nonzero_indices.(alg.sparsity_in), nonzero_indices.(alg.sparsity_out)
    (load = (i, k) -> :(arg[$i][$(index_in[i][k])]), store = (j, k, value) -> :(res[$j][$(index_out[j][k])] = $value))
end

"The keywords `place_in` and `place_out` of `framed_body` for arrays in matrix shape; `index` is that of `nonzero_call`."
matrix_places(alg, index) =
    (place_in = i -> is_dense(alg.sparsity_in[i]) ? :k : :($(index(:in, i))[k]),
     place_out = j -> is_dense(alg.sparsity_out[j]) ? :k : :($(index(:out, j))[k]))

"""
    inplace_function(alg, signature, frame, core, index, ref, key) -> Expr

Return the definition of the function `signature(res, arg)` on arrays in matrix shape,
which reads and writes the arrays directly. `frame` is that of `entry_function`. A sparse
matrix among the arrays, which is possible when a sparsity pattern has structural zeros,
sends the call to `core`, the function on vectors of nonzeros.

The generated function leaves one result of `alg` in each array of `res`, in column-major
order, with zero at each structural zero.
"""
function inplace_function(alg, signature, frame, core, index, ref, key)
    tables = index_tables(alg)
    sparse = isempty(tables) ? Any[] : Any[Expr(:if,
        foldl((a, b) -> :($a || $b), (:($(ref(:Helpers, :is_stored))($(kind === :in ? :arg : :res)[$k])) for ((kind, k), _) in tables)),
        Expr(:block, nonzero_call(alg, core, index, ref), :(return res)))]
    body = frame === nothing ? Any[inbounds_block(whole_statements(alg, ref; matrix_access(alg)...))] :
           framed_body(alg, frame, ref, key; matrix_places(alg, index)...)
    Expr(:function, signature, Expr(:block, count_checks(alg)..., shape_checks(alg; results = true)...,
        zero_fills(alg)..., sparse..., body..., :(return res)))
end

argument_names(alg) = [Symbol(:arg, i) for i in eachindex(alg.sparsity_in)]

returned(results) = length(results) == 1 ? only(results) : Expr(:tuple, results...)

static_array(ref) = ref(:StaticArraysCore, :SArray)

static_type(type, dims) = :($type{Tuple{$(dims...)},T,$(length(dims)),$(prod(dims))})

const ELEMENT_TYPE = :(T = promote_type(Float64, map(eltype, arg)...))

"""
    outofplace_function(alg, signature, inplace, ref) -> Expr

Return the definition of the function `signature(arg1, arg2, ...)` that makes a `Vector` or
a `Matrix` per result, fills them with `inplace`, the function on arrays in matrix shape,
and returns them.
"""
outofplace_function(alg, signature, inplace, ref) =
    Expr(:function, signature, Expr(:block, :(arg = $(Expr(:tuple, argument_names(alg)...))), ELEMENT_TYPE,
        :(res = $(Expr(:tuple, (:(Array{T}(undef, $(dimensions(sp)...))) for sp in alg.sparsity_out)...))),
        :($inplace(res, arg)),
        :(return $(returned([:(res[$j]) for j in eachindex(alg.sparsity_out)])))))

"""
    static_function(alg, signature, frame, index, ref, key) -> Expr

Return the definition of the out-of-place function with static arrays. It builds the static
arrays from local variables, or from the work vector of the `frame`, so it allocates no
memory.
"""
function static_function(alg, signature, frame, index, ref, key)
    index_out = nonzero_indices.(alg.sparsity_out)
    values = [Any[0.0 for _ in 1:prod(dimensions(sp))] for sp in alg.sparsity_out]
    body = if frame === nothing
        keep(j, k, value) = (values[j][index_out[j][k]] = value; nothing)
        Any[inbounds_block(whole_statements(alg, ref; load = matrix_access(alg).load, store = keep))]
    else
        offset_out = frame[1][2]
        for (j, indices) in enumerate(index_out), (k, place) in enumerate(indices)
            values[j][place] = :(w[$(offset_out[j] + k)])
        end
        framed_body(alg, frame, ref, key; place_in = matrix_places(alg, index).place_in, results = false)
    end
    SArray = static_array(ref)
    results = [:($(static_type(SArray, dimensions(sp)))($(Expr(:tuple, values[j]...))))
               for (j, sp) in enumerate(alg.sparsity_out)]
    Expr(:function, signature, Expr(:block, :(arg = $(Expr(:tuple, argument_names(alg)...))),
        shape_checks(alg; results = false)..., ELEMENT_TYPE, body...,
        :(return $(Expr(:macrocall, Symbol("@inbounds"), nothing, returned(results))))))
end

"Inputs and outputs that need a table of indices: `(kind, k) => indices`."
index_tables(alg) = [(kind, k) => nonzero_indices(sp)
                     for (kind, patterns) in ((:in, alg.sparsity_in), (:out, alg.sparsity_out))
                     for (k, sp) in enumerate(patterns) if !is_dense(sp) && C.nnz(sp) > 0]

core_name(name::Symbol) = Symbol(outofplace_name(name), :_nonzeros!)

"Whether the out-of-place function has a method for ordinary arrays, and one for static arrays."
methods_wanted(alg, force_SA::Bool) = (!force_SA, force_SA || !isempty(alg.sparsity_in))

"""
    form_definitions(alg, name, chunk_size, ref, force_SA) -> Vector{Expr}

Return the named definitions that follow those of the function on nonzeros
`core_name(name)`, whose sub-functions they share: the tables of indices, the in-place
function `name(res, arg)`, and the out-of-place function, whose name is `name` without `!`.

The out-of-place function has a method for a static array as its first argument, which
returns static arrays. With `force_SA` that is its only method, for any argument. `julia`
is that of `mx_definitions`.
"""
function form_definitions(alg, name::Symbol, chunk_size::ChunkSize, ref, force_SA::Bool; key = identity, julia = identity)
    base, arguments = outofplace_name(name), argument_names(alg)
    table(kind, k) = Symbol(base, :_index_, kind, k)
    definitions = Expr[Expr(:const, :($(table(kind, k)) = $(Expr(:vect, indices...))))
                       for ((kind, k), indices) in index_tables(alg)]
    frame = named_frame(alg, core_name(name), chunk_size, ref; julia)
    ordinary, static = methods_wanted(alg, force_SA)
    typed = force_SA || !static ? arguments : Any[:($(arguments[1])::$(ref(:StaticArraysCore, :StaticArray))), arguments[2:end]...]
    push!(definitions, inplace_function(alg, :($name(res, arg)), frame, core_name(name), table, ref, key(name)))
    ordinary && push!(definitions, outofplace_function(alg, :($base($(arguments...))), name, ref))
    static && push!(definitions, static_function(alg, :($base($(typed...))), frame, table, ref, key(name)))
    named_calls(alg, definitions, julia)
end

"""
    runtime_forms(alg, chunk_size, ref, force_SA) -> (out_of_place, in_place)

Return the two functions as runtime generated functions. Each holds the functions that it
calls and the tables of indices in its body. The out-of-place function returns static
arrays when its first argument is a static array, or always with `force_SA`.
"""
function runtime_forms(alg, chunk_size::ChunkSize, ref, force_SA::Bool)
    generate(ex) = RuntimeGeneratedFunction(@__MODULE__, @__MODULE__, ex)
    hold(g) = RuntimeGeneratedFunctions.drop_expr(g)
    tables = Dict(index_tables(alg))
    index(kind, k) = tables[(kind, k)]
    arguments = argument_names(alg)
    signature = Expr(:tuple, arguments...)
    key = unique_key(alg.name)
    frame = runtime_frame(alg, chunk_size, ref)
    # Only a sparse matrix, which needs a pattern with structural zeros, sends a call to the function on nonzeros.
    core = isempty(tables) ? nothing : hold(generate(entry_function(alg, :((res, arg)), frame, ref, key)))
    inplace = generate(inplace_function(alg, :((res, arg)), frame, core, index, ref, key))
    ordinary, static = methods_wanted(alg, force_SA)
    with_arrays = ordinary ? generate(outofplace_function(alg, signature, hold(inplace), ref)) : nothing
    with_static = static ? generate(static_function(alg, signature, frame, index, ref, key)) : nothing
    outofplace = !ordinary ? with_static : !static ? with_arrays :
        generate(Expr(:function, signature, Expr(:block,
            :(return $(arguments[1]) isa $(ref(:StaticArraysCore, :StaticArray)) ?
                     $(hold(with_static))($(arguments...)) : $(hold(with_arrays))($(arguments...))))))
    # Without its expression a function is a value without fields, which a call passes without allocation.
    hold(outofplace), hold(inplace)
end
