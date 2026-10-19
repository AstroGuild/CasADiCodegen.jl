# The modelling interface that `using CasADiCodegen` gives, with no module alias.
import LinearAlgebra
import SpecialFunctions

module ApiUser
using CasADiCodegen
model() = (x = SX.sym("x", 2); (x, [sin(x[1]) * x[2]; x[1]^2]))
function build()
    x, y = model()
    CasadiFunction("f", [x], [y, jacobian(y, x)])
end
end

"Evaluate a scalar expression in the symbols `args` at the numbers `values`."
function evaluate(expr, args, values)
    g = build_function(CasADiCodegen.Function("t", collect(args), [expr]); nonzeros = true, expression = Val{false})
    g([zeros(1)], Tuple([v] for v in values))[1][1]
end

@testset "using CasADiCodegen is enough to write a model" begin
    f = ApiUser.build()
    g = build_function(f; nonzeros = true, expression = Val{false})
    res = g([zeros(2), zeros(3)], ([0.3, 1.7],))
    @test res[1] == [sin(0.3) * 1.7, 0.3^2]
    @test res[2] == [cos(0.3) * 1.7, 2 * 0.3, sin(0.3)]
end

@testset "Base functions work on symbols" begin
    x, y = SX.sym("x"), SX.sym("y")
    unary = [asinh, acosh, atanh, log1p, expm1, log10, log2, abs2, inv,
             SpecialFunctions.erf, SpecialFunctions.erfinv]
    @testset "$f" for f in unary
        a = f in (acosh,) ? 1.7 : 0.4
        @test evaluate(f(x), (x,), (a,)) ≈ f(a) rtol = 1e-7
    end
    # `inv` of a matrix is the matrix inverse, as in Julia, and not the reciprocal of each element.
    M = [4.0 1.0; 0.5 3.0]
    @testset "inverse of a matrix, $T" for T in (SX, MX)
        A = T.sym("A", 2, 2)
        for inverse in (T === MX ? (inv(A), inv(A, "qr")) : (inv(A),))
            g = build_function(CasADiCodegen.Function("t", [A], [inverse]); expression = Val{false})[1]
            @test g(M) ≈ inv(M) rtol = 1e-14
        end
        @test_throws DimensionMismatch inv(T.sym("B", 2, 3))
        T === MX && @test_throws DimensionMismatch inv(T.sym("B", 2, 3), "qr")
    end
    binary = [min, max, atan, hypot, rem, copysign]
    @testset "$f" for f in binary, (a, b) in ((0.4, -1.7),)
        @test evaluate(f(x, y), (x, y), (a, b)) ≈ f(a, b) rtol = 1e-14
        @test evaluate(f(x, b), (x,), (a,)) ≈ f(a, b) rtol = 1e-14
        @test evaluate(f(a, y), (y,), (b,)) ≈ f(a, b) rtol = 1e-14
    end

    # Logical operations give 1 or 0, as everywhere in CasADi.
    truth(e, a, b) = evaluate(e, (x, y), (a, b)) == 1
    for (a, b) in ((1.0, 2.0), (2.0, 1.0), (1.0, 1.0))
        @test truth(x != y, a, b) == (a != b)
        @test truth((x < y) & (x != y), a, b) == (a < b)
        @test truth((x < y) | (x > y), a, b) == (a != b)
        @test truth(!(x < y), a, b) == !(a < b)
        @test evaluate(ifelse(x < y, x, y), (x, y), (a, b)) == min(a, b)
        @test evaluate(ifelse(x < y, 10.0, y), (x, y), (a, b)) == (a < b ? 10.0 : b)
    end
end

@testset "matrix (MX) symbols get the same functions" begin
    m = MX.sym("m")
    f = CasADiCodegen.Function("t", [m], [hypot(min(m, 2.0), log1p(m)) + ifelse(m != 1.0, asinh(m), m)])
    a = 0.4
    @test build_function(f; nonzeros = true, expression = Val{false})([zeros(1)], ([a],))[1][1] ≈ hypot(min(a, 2.0), log1p(a)) + asinh(a)
end

@testset "LinearAlgebra functions" begin
    u, v = SX.sym("u", 3), SX.sym("v", 3)
    a, b = [1.0, -2.0, 0.5], [0.25, 3.0, -1.5]
    f = CasADiCodegen.Function("t", [u, v], [LinearAlgebra.dot(u, v), LinearAlgebra.cross(u, v)])
    res = build_function(f; nonzeros = true, expression = Val{false})([zeros(1), zeros(3)], (a, b))
    @test res[1][1] ≈ LinearAlgebra.dot(a, b)
    @test res[2] ≈ LinearAlgebra.cross(a, b)
    # `norm` is the Frobenius norm, for a vector and for a matrix, as in LinearAlgebra.
    for T in (SX, MX)
        w, A = T.sym("w", 3), T.sym("A", 2, 2)
        n = CasADiCodegen.Function("n", [w, A], [LinearAlgebra.norm(w), LinearAlgebra.norm(A)])
        values = C.nonzeros.(n(C.DM(a), C.DM([1.0 2.0; 3.0 4.0])))
        @test values[1][1] ≈ LinearAlgebra.norm(a) && values[2][1] ≈ sqrt(30)
    end
end

@testset "tools: operations of a function and the first NaN" begin
    x, p = SX.sym("x", 2), SX.sym("p")
    f = CasADiCodegen.Function("f", [x, p], [vertcat(sqrt(x[1] - p) * x[2], log(x[2]) + sin(x[1]))])
    histogram = CasADiCodegen.instruction_histogram(f)
    @test histogram isa Vector{Pair{Symbol,Int}}
    @test Dict(histogram)[:OP_INPUT] == 3 && Dict(histogram)[:OP_SQRT] == 1 && Dict(histogram)[:OP_OUTPUT] == 2
    @test issorted(last.(histogram); rev = true)
    @test sum(last, histogram) == C.n_instructions(f)
    # No NaN, then the square root of a negative number, then a NaN in an argument.
    @test CasADiCodegen.nan_trace(f, [2.0, 3.0], 1.0) === nothing
    found = CasADiCodegen.nan_trace(f, [2.0, 3.0], 5.0)
    @test found.operation === :OP_SQRT && found.operands == (-3.0,) && isnan(found.result)
    @test C.instruction_id(f, found.instruction - 1) == C.OP_SQRT
    @test occursin("sqrt", found.text)
    given = CasADiCodegen.nan_trace(f, [NaN, 3.0], 1.0)
    @test given.operation === :OP_INPUT && given.text == "nonzero 1 of argument 1 (i0)"
    # A matrix function is expanded, and an argument with a sparse pattern is given whole or by its nonzeros.
    A = MX.sym("A", C.Sparsity.diag(2))
    g = CasADiCodegen.Function("g", [A], [log(A[1, 1]) + A[2, 2]])
    @test CasADiCodegen.nan_trace(g, [-1.0 0.0; 0.0 2.0]).operation === :OP_LOG
    @test CasADiCodegen.nan_trace(g, [1.0, 2.0]) === nothing
    # A constant of the function is an operand like any other.
    c = SX.sym("c")
    shifted = CasADiCodegen.Function("shifted", [c], [sqrt(c - 2.5)])
    @test CasADiCodegen.nan_trace(shifted, 1.0).operands == (-1.5,) && CasADiCodegen.nan_trace(shifted, 3.0) === nothing
    @test_throws ArgumentError CasADiCodegen.nan_trace(g, [1.0, 2.0, 3.0])
    @test_throws ArgumentError CasADiCodegen.nan_trace(f, [2.0, 3.0])
    # Functions with Julia functions in them: the histogram counts the calls, the trace needs scalar code.
    twice = callback(v -> 2 .* v, "twice", (2,), (2,))
    v = MX.sym("v", 2)
    h = CasADiCodegen.Function("h", [v], [twice(sin(v))])
    @test Dict(CasADiCodegen.instruction_histogram(h))[:OP_CALL] == 1
    @test Dict(CasADiCodegen.instruction_histogram(h; expand = false))[:OP_CALL] == 1
    @test_throws ArgumentError CasADiCodegen.nan_trace(h, [1.0, 2.0])
end

# The front end of CasADi gives an integer, or a whole Float64, in a Dict of options to CasADi as `true`.
# CasADiCodegen.jl gives each number to CasADi with its own type.
@testset "options of CasADi keep their numbers" begin
    x = MX.sym("x")
    # Integer: seven steps of the classic Runge-Kutta method on x' = -x, against its exact formula.
    rk = C.integrator("rk", "rk", Dict("x" => x, "ode" => -x), 0.0, 1.0, Dict("number_of_finite_elements" => 7))
    h = 1 / 7
    @test Float64(rk(Dict("x0" => C.DM(1.0)))["xf"]) ≈ (1 - h + h^2 / 2 - h^3 / 6 + h^4 / 24)^7 rtol = 1e-14
    # A whole Float64: the eigenvalue -1 is clipped to the margin 2.
    H = MX.sym("H")
    clip = CasADiCodegen.Function("clip", [H], [C.convexify(H, Dict("strategy" => "eigen-clip", "margin" => 2.0))])
    @test Float64(clip(C.DM(-1.0))) == 2.0
    # A Dict in a Dict: the Newton method of collocation needs more than one iteration.
    stiff = Dict("rootfinder" => "newton", "rootfinder_options" => Dict("max_iter" => 50, "error_on_fail" => true))
    cubic = C.integrator("cubic", "collocation", Dict("x" => x, "ode" => -x^3), 0.0, 1.0, stiff)
    @test Float64(cubic(Dict("x0" => C.DM(2.0)))["xf"]) ≈ 2 / sqrt(1 + 8) rtol = 1e-4
    # Vectors of integers and of whole Float64: the constraint z <= 0 selects the root -2 of z^2 = 4.
    z = MX.sym("z", 2)
    negative = C.rootfinder("negative", "kinsol", CasADiCodegen.Function("g", [z], [z .^ 2 .- 4]),
                            Dict("constraints" => [-1, -1], "u_scale" => [1.0, 2.0]))
    @test C.nonzeros(negative(C.DM([-1.0, -1.0]))) ≈ [-2.0, -2.0] rtol = 1e-6
end
