# Numbers in the options of CasADi.
#
# The front end that SWIG generates converts each value of a Dict of options to a
# `GenericType` of CasADi, and it tries the type `bool` first, which accepts an
# integer and a whole Float64. Thus `"number_of_finite_elements" => 7` reaches
# CasADi as `true`, that is 1, and `"margin" => 2.0` as 1.0. A `GenericType` that
# Julia gives is passed as it is, so each number becomes a `GenericType` of its own
# type here, made by the deserializer of CasADi. The functions of the front end
# get this conversion when the module is included (see front_end.jl).

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
argument_name(a::Expr) = Meta.isexpr(a, (:(::), :kw)) ? argument_name(a.args[1]) : nothing

function call_signature(signature)
    while Meta.isexpr(signature, :where)
        signature = signature.args[1]
    end
    Meta.isexpr(signature, :call) ? signature : nothing
end

"""
    typed_definitions!(ex, count::Ref{Int}) -> ex

Rewrite each method definition in `ex` that has an argument of options, so that
its body first converts that argument with `typed_options`; `count` is increased
by the number of rewritten methods.
"""
function typed_definitions!(ex, count::Ref{Int})
    ex isa Expr || return ex
    if Meta.isexpr(ex, (:(=), :function)) && (signature = call_signature(ex.args[1])) !== nothing
        names = filter(option_argument, filter(!isnothing, map(argument_name, signature.args[2:end])))
        if !isempty(names)
            ex.args[2] = Expr(:block, (:($n = $typed_options($n)) for n in names)..., ex.args[2])
            count[] += 1
        end
        return ex
    end
    foreach(a -> typed_definitions!(a, count), ex.args)
    ex
end
