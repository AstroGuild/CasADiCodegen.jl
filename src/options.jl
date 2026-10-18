# Numbers in the options of CasADi.
#
# The front end that SWIG generates converts each value of a Dict of options to a
# `GenericType` of CasADi, and it tries the type `bool` first, which accepts an
# integer and a whole Float64. Thus `"number_of_finite_elements" => 7` reaches
# CasADi as `true`, that is 1, and `"margin" => 2.0` as 1.0. A `GenericType` that
# Julia gives is passed as it is, so each number becomes a `GenericType` of its own
# type here, made by the deserializer of CasADi. CasADiNative.jl passes the Dict
# to the wrapper as it is, so this package gives each function of `C` that takes
# options a method whose argument of options is an `AbstractDict`: it converts
# the Dict and calls the method of the front end (see `typed_methods`).

# The codes of `casadi::TypeID` for the types that a number of Julia can have. A
# vector of vectors needs none: the front end gives it the right type.
const OT_INT, OT_DOUBLE, OT_INTVECTOR, OT_DOUBLEVECTOR = 2, 3, 5, 8

# The serialization of a `GenericType`, up to its type: CasADi writes the header of
# the stream, the tag of a `GenericType`, then the code of the type and the value.
function serialized_header()
    serializer = C.StringSerializer(Dict{String,Any}())
    # The method of `pack` for a GenericType; its generated wrapper takes no `Bool`.
    pack = Libdl.dlsym(Libdl.dlopen(C._lib), :_swig_SerializerBase_SerializerBase_pack__SWIG_6)
    GC.@preserve serializer ccall(pack, Cvoid, (Ptr{Cvoid}, Any), serializer.ptr, true)
    C._check(nothing)
    stream = serialized_bytes(C.encode(serializer))
    stream[end-4:end] == [0x01, 0x00, 0x00, 0x00, 0x01] ||
        throw(AssertionError("the serialization of a GenericType of CasADi has changed"))
    stream[1:end-5]
end
const GENERIC_HEADER = Base.OncePerProcess{Vector{UInt8}}(serialized_header)

# The string encoding of CasADi: each byte is two letters from 'a', the low half first.
serialized_bytes(text) = [UInt8((text[i] - 'a') | (text[i+1] - 'a') << 4) for i in 1:2:length(text)]
serialized_text(bytes) = String([c for b in bytes for c in ('a' + (b & 0x0f), 'a' + (b >> 4))])

"A `GenericType` of CasADi of the type `code`, whose value has the serialization `bytes`."
function generic_value(code, bytes)
    stream = vcat(GENERIC_HEADER(), reinterpret(UInt8, [Int32(code)]), bytes)
    deserializer = C.StringDeserializer(serialized_text(stream))
    C.pop_type(deserializer)
    C.blind_unpack_generictype(deserializer)
end

# CasADi writes a vector as its length, then its elements, each as 8 bytes.
serial(v::Real) = collect(reinterpret(UInt8, [v]))
serial(v::AbstractVector{<:Real}) = vcat(serial(Int64(length(v))), collect(reinterpret(UInt8, v)))

"""
    option_value(value)

`value` as a value of a Dict of options of CasADi that keeps its type: an integer
is an integer of CasADi, any other real number a double, and so for vectors. A
Dict has its values converted; other values are unchanged.
"""
option_value(value) = value
option_value(value::Bool) = value
option_value(value::AbstractVector{Bool}) = value
option_value(value::Integer) = generic_value(OT_INT, serial(Int64(value)))
option_value(value::Real) = generic_value(OT_DOUBLE, serial(Float64(value)))
option_value(value::AbstractVector{<:Integer}) = generic_value(OT_INTVECTOR, serial(Int64.(value)))
option_value(value::AbstractVector{<:Real}) = generic_value(OT_DOUBLEVECTOR, serial(Float64.(value)))
option_value(value::AbstractDict) = typed_options(value)

"""
    typed_options(options)

The Dict of options `options` with each value converted by `option_value`, so that
CasADi gets the numbers of Julia with their types. Any other argument is returned as it is.
"""
typed_options(options) = options
typed_options(options::AbstractDict) = Dict{String,Any}(string(k) => option_value(v) for (k, v) in options)

# An argument of the front end that holds a Dict of options: `opts`, `options`,
# `plugin_options`, `solver_options` and so on.
option_argument(name) = name === :opts || endswith(string(name), "options")

argument_name(a::Symbol) = a
argument_name(a::Expr) = Meta.isexpr(a, :(::)) && length(a.args) == 2 ? a.args[1] : nothing
argument_type(a) = Meta.isexpr(a, :(::)) ? a.args[end] : :Any

# A type of the generated module as an expression that names its bindings in `C`.
in_front_end(ex::Symbol) = isdefined(C, ex) ? GlobalRef(C, ex) : ex
in_front_end(ex::Expr) = Expr(ex.head, map(in_front_end, ex.args)...)
in_front_end(ex) = ex

"""
    option_signatures(path) -> Vector{Expr}

The signatures of the methods in the generated module at `path` that have an argument of
options, as `:call` expressions.
"""
function option_signatures(path)
    found = Expr[]
    function walk(ex)
        ex isa Expr || return
        if Meta.isexpr(ex, (:(=), :function)) && Meta.isexpr(ex.args[1], :call)
            any(option_argument, filter(!isnothing, map(argument_name, ex.args[1].args[2:end]))) && push!(found, ex.args[1])
            return
        end
        foreach(walk, ex.args)
    end
    walk(Meta.parseall(read(path, String)))
    length(found) > 100 || throw(AssertionError("only $(length(found)) functions of the front end take options; the front end has changed"))
    found
end

"""
    typed_methods(signature) -> Vector{Expr}

The definitions of the methods that convert the Dicts of options of the method of `C` with
`signature` and then call that method: one method for each nonempty set of its arguments of
options, with these arguments typed `AbstractDict`.
"""
function typed_methods(signature)
    f = getfield(C, signature.args[1])
    arguments = signature.args[2:end]
    names = [something(argument_name(a), Symbol("argument", i)) for (i, a) in enumerate(arguments)]
    original = Core.eval(@__MODULE__, :(Tuple{$(map(in_front_end ∘ argument_type, arguments)...)}))
    which(f, original).sig == Tuple{Core.Typeof(f), original.parameters...} ||
        throw(AssertionError("the generated module has no method $(signature)"))
    options = findall(option_argument, names)
    subsets = [options[[isodd(s >> (i - 1)) for i in eachindex(options)]] for s in 1:2^length(options)-1]
    map(subsets) do typed
        narrowed = [i in typed ? :($(names[i])::AbstractDict) : :($(names[i])::$(in_front_end(argument_type(arguments[i])))) for i in eachindex(arguments)]
        values = [i in typed ? :($typed_options($(names[i]))) : names[i] for i in eachindex(arguments)]
        :(function $C.$(signature.args[1])($(narrowed...))
              invoke($f, $original, $(values...))
          end)
    end
end
