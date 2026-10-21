"""
    Traced{S}(value::S) <: Real

A real number that records the operations on it as a CasADi expression of type `S`, which
is `SX` or `MX`, so that generic Julia code traces into a CasADi graph.

Arithmetic, the elementary functions, `min`, `max`, `clamp`, `ifelse` and `norm` give
`Traced` values; a plain number promotes to `Traced`. A comparison gives a traced
condition, not a `Bool`, so an `if`, `&&` or `? :` on traced values throws a `TypeError`
instead of following one branch. Use `ifelse`, `min`, `max` or `clamp` for a choice that
depends on the input, or [`CasADiCodegen.callback`](@ref) for a Julia function with branches.

See [`CasADiCodegen.traced`](@ref traced) and [`CasADiCodegen.untraced`](@ref untraced).
"""
struct Traced{S<:Symbolic} <: Real
    value::S
    Traced{S}(value::S) where {S<:Symbolic} = new{S}(value)
end
Traced(value::S) where {S<:Symbolic} = Traced{S}(value)
Traced{S}(x::Traced{S}) where {S<:Symbolic} = x
Traced{S}(x::Real) where {S<:Symbolic} = Traced{S}(convert(S, Float64(x)))

Base.convert(::Type{Traced{S}}, x::Real) where {S<:Symbolic} = Traced{S}(x)
Base.convert(::Type{Traced{S}}, x::Traced{S}) where {S<:Symbolic} = x
Base.promote_rule(::Type{Traced{S}}, ::Type{<:Real}) where {S<:Symbolic} = Traced{S}

Base.zero(::Type{Traced{S}}) where {S<:Symbolic} = Traced{S}(0.0)
Base.one(::Type{Traced{S}}) where {S<:Symbolic} = Traced{S}(1.0)
Base.zero(x::Traced) = zero(typeof(x))
Base.one(x::Traced) = one(typeof(x))
Base.float(x::Traced) = x
Base.show(io::IO, x::Traced) = print(io, "Traced(", x.value, ")")

for f in (:+, :-, :*, :/, :^, :atan, :hypot, :min, :max, :&, :|)
    @eval Base.$f(a::Traced{S}, b::Traced{S}) where {S<:Symbolic} = Traced{S}($f(a.value, b.value))
end
for (f, c) in ((:<, :lt), (:<=, :le), (:(==), :eq))
    @eval Base.$f(a::Traced{S}, b::Traced{S}) where {S<:Symbolic} = Traced{S}(C.$c(a.value, b.value))
end
Base.:^(a::Traced{S}, n::Integer) where {S<:Symbolic} = Traced{S}(a.value^n)

for f in (:-, :sqrt, :exp, :log, :log2, :log10, :log1p, :expm1, :abs, :abs2, :inv, :!,
          :sin, :cos, :tan, :asin, :acos, :atan, :sinh, :cosh, :tanh, :asinh, :acosh, :atanh)
    @eval Base.$f(a::Traced{S}) where {S<:Symbolic} = Traced{S}($f(a.value))
end
Base.sincos(a::Traced) = (sin(a), cos(a))
Base.clamp(x::Traced, lo::Real, hi::Real) = min(max(x, lo), hi)

"""
    ifelse(condition::Traced, a, b)

Return the traced selection: `a` where `condition` is not zero, else `b`. Both values stay
in the graph, as with CasADi `if_else`, and the derivative is that of the selected value.
"""
Base.ifelse(condition::Traced{S}, a::Real, b::Real) where {S<:Symbolic} =
    Traced{S}(C.if_else(condition.value, convert(Traced{S}, a).value, convert(Traced{S}, b).value))

# The norms of LinearAlgebra and StaticArrays compare values to avoid overflow, which a trace cannot do.
LinearAlgebra.norm(v::AbstractArray{<:Traced}) = sqrt(sum(abs2, v))
LinearAlgebra.norm(v::StaticArrays.StaticArray{<:Tuple,<:Traced}) = sqrt(sum(abs2, v))

"""
    traced(x::Union{SX,MX}) -> Vector{Traced}

Return the elements of the symbolic column vector `x` as a vector of [`CasADiCodegen.Traced`](@ref Traced),
the argument of a generic Julia function to trace.

# Examples
```julia
using CasADiCodegen, LinearAlgebra

acceleration(r, μ) = -μ * r / norm(r)^3          # generic Julia code
r = SX.sym("r", 3)
a = acceleration(CasADiCodegen.traced(r), 398600.4418)
f = CasadiFunction("a", [r], [CasADiCodegen.untraced(a)])
g, g! = build_function(f; expression = Val{false})
```
"""
function traced(x::S) where {S<:Symbolic}
    @requires size(x, 2) == 1 "traced takes a column vector; got a matrix of size $(size(x))"
    Traced{S}[Traced{S}(x[i]) for i in 1:size(x, 1)]
end

"""
    untraced(v) -> SX or MX

Return the CasADi expression of the traced value `v`, or the column vector of the
expressions of the elements of the vector `v`. A plain number in `v` becomes a constant.
"""
untraced(x::Traced) = x.value
function untraced(v::AbstractVector)
    S = mapreduce(x -> x isa Traced ? typeof(x.value) : Union{}, typejoin, v; init = Union{})
    @requires S === SX || S === MX "untraced needs a vector with traced values of one type, SX or MX; got the element types $(unique(typeof.(v)))"
    column = C.vertcat(S[convert(Traced{S}, x).value for x in collect(v)])
    @ensures size(column) == (length(v), 1) "untraced must give one element per element of the vector"
    column
end
