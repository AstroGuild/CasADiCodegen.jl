# Methods of ordinary Julia functions that the official front end leaves
# without a definition for symbols.

"A CasADi symbolic matrix: scalar graph (`SX`) or matrix graph (`MX`)."
const Symbolic = Union{SX,MX}

# Functions of `Base` that the front end does not cover. Each maps to the CasADi
# operation with the same meaning for ordinary numbers.
for (f, c) in ((:asinh, :asinh), (:acosh, :acosh), (:atanh, :atanh), (:log1p, :log1p),
               (:expm1, :expm1), (:log10, :log10), (:!, :not))
    @eval Base.$f(x::Symbolic) = C.$c(x)
end
Base.log2(x::Symbolic) = log(x) / log(2.0)
Base.abs2(x::Symbolic) = x * x

"""
    inv(A)
    inv(A, lsolver)

Return the inverse of a symbolic square matrix, or the reciprocal of a scalar.

For an `MX` matrix, `inv` of the CasADi front end returns the reciprocal of
each element. This method takes the inverse from the linear solver `"qr"`, or
from `lsolver`. CasADi accepts `lsolver` for `MX` only.

Throws `DimensionMismatch` when `A` is not square.
"""
function Base.inv(A::Symbolic)
    C.is_scalar(A) && return 1 / A
    size(A, 1) == size(A, 2) || throw(DimensionMismatch("the matrix is not square: its size is $(size(A))"))
    A isa SX ? C.inv(A) : C.inv(A, "qr")
end
function Base.inv(A::MX, lsolver::AbstractString)
    size(A, 1) == size(A, 2) || throw(DimensionMismatch("the matrix is not square: its size is $(size(A))"))
    C.inv(A, lsolver)
end
SpecialFunctions.erf(x::Symbolic) = C.erf(x)
SpecialFunctions.erfinv(x::Symbolic) = C.erfinv(x)

for (f, c) in ((:min, :fmin), (:max, :fmax), (:atan, :atan2), (:hypot, :hypot), (:rem, :fmod),
               (:copysign, :copysign), (:&, :and), (:|, :or), (:!=, :ne))
    @eval begin
        Base.$f(x::T, y::T) where {T<:Symbolic} = C.$c(x, y)
        Base.$f(x::T, y::Real) where {T<:Symbolic} = C.$c(x, convert(T, y))
        Base.$f(x::Real, y::T) where {T<:Symbolic} = C.$c(convert(T, x), y)
    end
end

"""
    ifelse(condition, a, b)

Return the symbolic selection: `a` where `condition` is not zero, else `b`.
Both branches are evaluated, as in CasADi `if_else`.
"""
Base.ifelse(condition::T, a::Union{T,Real}, b::Union{T,Real}) where {T<:Symbolic} =
    C.if_else(condition, convert(T, a), convert(T, b))

# The front end exports its own `dot` and `cross`; these make the LinearAlgebra
# functions of the same name work too.
LinearAlgebra.dot(a::T, b::T) where {T<:Symbolic} = Front.dot(a, b)
LinearAlgebra.cross(a::T, b::T) where {T<:Symbolic} = Front.cross(a, b)
# As in LinearAlgebra, `norm` is the Frobenius norm: the 2-norm of a vector.
LinearAlgebra.norm(x::Symbolic) = C.norm_fro(x)
