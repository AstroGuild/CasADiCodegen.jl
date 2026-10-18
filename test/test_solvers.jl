# A solver of CasADi in the graph of a function, replaced in the generated
# code by a solver of the SciML ecosystem that the user selects with
# `CasADiCodegen.Solvers`. CasADi with tight tolerances and exact solutions are the oracles.
include("ode_helpers.jl")
import ForwardDiff
import SciMLBase
using OrdinaryDiffEqVerner: Vern9, Vern7
using OrdinaryDiffEqRosenbrock: Rodas5P
using SimpleNonlinearSolve: SimpleNewtonRaphson
const K = CasADiCodegen.Codegen
using CasADiCodegen: Solvers, Solver

native(f; kwargs...) = build_function(f; nonzeros = true, expression = Val{false}, expand = false, kwargs...)
evaluated(g, f, nz) = g([fill(NaN, n) for n in nnz_out(f)], Tuple(nz))
agree(a, e; rtol) = length(a) == length(e) && all(isapprox(x, y; rtol, atol = 1e-12) for (x, y) in zip(a, e))
all_agree(actual, expected; rtol) = all(agree(a, e; rtol) for (a, e) in zip(actual, expected))
# One compiled solver for all integrators of the group: the specialization is a matter of the integrator group.
const PRECISE = Solver(Vern9(); abstol = 1e-13, reltol = 1e-13, specialize = SciMLBase.AutoSpecialize)

@testset "the selection of solvers" begin
    x = MX.sym("x", 2)
    rule = C.integrator("rule", "cvodes", Dict("x" => x, "ode" => -x), 0.0, 1.0)
    one = Solver(rule, Vern7(); abstol = 1e-9)
    @test_throws "an override needs the function of CasADi that it replaces" Solvers(overrides = (PRECISE,))
    @test_throws "has a function of CasADi; give it in overrides" Solvers(ode = one)
end

"The model of the test below, integrated arc by arc with the solver itself: the states at the three times, and the quadratures."
function pendulum_reference(x0, rate, controls)
    T = promote_type(eltype(x0), eltype(rate), eltype(controls))
    rhs(du, s, q, time) = (du[1] = s[2]; du[2] = -q[1] * sin(s[1]) + q[2] * time; du[3] = s[1]^2 + s[2]^2; nothing)
    state, start, finals, sums = T[x0; 0], 0.0, T[], T[]
    for (k, stop) in enumerate((0.5, 1.0, 2.0))
        # Loop invariant: `state` is the state with the quadrature at the time `start`.
        problem = SciMLBase.ODEProblem(rhs, state, (start, stop), T[rate[1], controls[k]])
        state = SciMLBase.solve(problem, Vern9(); abstol = 1e-13, reltol = 1e-13, save_everystep = false).u[end]
        append!(finals, state[1:2])
        push!(sums, state[3])
        start = stop
    end
    finals, sums
end

@testset "integrator with a variable step" begin
    x, p, u, t = MX.sym("x", 2), MX.sym("p"), MX.sym("u", 1, 3), MX.sym("t")
    control = MX.sym("c")
    dae = Dict("x" => x, "p" => p, "u" => control, "t" => t, "ode" => C.vertcat([x[2], -p * C.sin(x[1]) + control * t]), "quad" => C.dot(x, x))
    rule = C.integrator("rule", "cvodes", dae, 0.0, [0.5, 1.0, 2.0])
    run(x0, parameter, controls) = rule(x0, MX(0, 1), parameter, controls, MX(), MX(), MX())
    final, quadrature = run(x, p, u)[1], run(x, p, u)[3]
    f = CasADiCodegen.Function("f", [x, p, u], [final, quadrature, C.jacobian(final, x), C.jacobian(quadrature, p), C.jacobian(final[:, 3], u)])
    values = [[0.4, -0.3], [1.7], [0.2, -0.1, 0.5]]
    # One Jacobian of the reference by all its arguments: the states are the rows 1 to 6, and the quadratures follow them.
    all_values = reduce(vcat, values)
    J = ForwardDiff.jacobian(v -> reduce(vcat, pendulum_reference(v[1:2], v[3:3], v[4:6])), all_values)
    expected = [pendulum_reference(values...)..., vec(J[1:6, 1:2]), J[7:9, 3], vec(J[5:6, 4:6])]
    solvers = Solvers(ode = PRECISE)
    @test_throws "CasADiCodegen.Solvers(ode = ...)" K.algorithm(f; expand = false)
    g = native(f; solvers)
    @test all_agree(evaluated(g, f, values), expected; rtol = 1e-9)
    # The function without derivatives keeps the compilation short.
    plain = CasADiCodegen.Function("plain", [x, p, u], [final])
    @testset "reverse mode" begin
        # The gradient of one number by all arguments, for which CasADi asks the integrator for adjoint sensitivities.
        cost = C.sumsqr(final) + quadrature[3]
        h = CasADiCodegen.Function("h", [x, p, u], [C.gradient(cost, C.vertcat([x, p, C.vec(u)]))])
        @test evaluated(native(h; solvers), h, values)[1] ≈ 2 * J[1:6, :]' * expected[1] + J[9, :] rtol = 1e-8
    end
    # The tolerances of the integrator of CasADi are those of the solver when the user gives none.
    # No public result names the tolerances in use, so the size of the error shows them.
    loose = evaluated(native(plain; solvers = Solvers(ode = Vern9())), plain, values)
    @test all_agree(loose, expected[1:1]; rtol = 1e-4)
    @test !all_agree(loose, expected[1:1]; rtol = 1e-11)
    @testset "a written module has the solver" begin
        text = sprint(io -> generate_julia(plain, io; module_name = :Written, name = :run!, expand = false, solvers))
        src = Module()
        Base.include_string(src, text)
        written = Base.invokelatest((r, a) -> src.Written.run_nonzeros!(r, a), [fill(NaN, 6)], Tuple(values))
        @test all_agree(written, expected[1:1]; rtol = 1e-9)
    end
end

@testset "one solver for one function" begin
    x, p = MX.sym("x", 2), MX.sym("p")
    dae = Dict("x" => x, "p" => p, "ode" => -p * x)
    fixed = C.integrator("fixed", "rk", dae, 0.0, 1.0)
    free = C.integrator("free", "cvodes", dae, 0.0, 1.0)
    call(rule) = rule(x, MX(0, 1), p, MX(0, 1), MX(), MX(), MX())[1]
    f = CasADiCodegen.Function("f", [x, p], [call(fixed), call(free), C.jacobian(call(fixed), p)])
    values = [[0.4, -0.3], [1.7]]
    exact = [0.4, -0.3] .* exp(-1.7)
    # The integrator with a fixed step keeps the Julia code of its own method, unless an override names it.
    # No public result names the method in use, so the error of the fixed step shows it.
    plain = evaluated(native(f; solvers = Solvers(ode = PRECISE)), f, values)
    @test !isapprox(plain[1], exact; rtol = 1e-9) && isapprox(plain[1], exact; rtol = 1e-3) && isapprox(plain[2], exact; rtol = 1e-11)
    named = evaluated(native(f; solvers = Solvers(ode = PRECISE, overrides = (Solver(fixed, Vern9(); abstol = 1e-13, reltol = 1e-13, specialize = SciMLBase.AutoSpecialize),))), f, values)
    @test isapprox(named[1], exact; rtol = 1e-11) && isapprox(named[3], -exact; rtol = 1e-10)
    # The override is for the function with that name and its derivatives only.
    @test_throws "function \"free\" is the integrator \"cvodes\" of CasADi" K.algorithm(f; expand = false, solvers = Solvers(overrides = (Solver(fixed, Vern9()),)))
    @test K.algorithm(f; expand = false, solvers = Solvers(overrides = (Solver(fixed, Vern9()), Solver(free, Vern7())))) isa K.MXAlgorithm
end

@testset "rootfinder" begin
    a, x, b = MX.sym("a"), MX.sym("x", 2), MX.sym("b", C.Sparsity.diag(2))
    residual = CasADiCodegen.Function("r", [a, x, b], [x * a, x^3 + C.mtimes(b, x) - a])
    values = [[2.0], [1.0, 1.0], [0.5, 3.0]]
    @testset "$plugin" for plugin in ("kinsol", "fast_newton")
        finder = C.rootfinder("finder", plugin, residual, Dict("implicit_input" => true, "implicit_output" => true, "abstol" => 1e-13))
        results = collect(finder(a, x, b))
        f = CasADiCodegen.Function("f", [a, x, b], [results..., C.jacobian(results[2], a), C.jacobian(results[2], b)])
        solvers = Solvers(nonlinear = Solver(SimpleNewtonRaphson(); abstol = 1e-13))
        @test_throws "CasADiCodegen.Solvers(nonlinear = ...)" K.algorithm(f; expand = false)
        # The two plugins take one path once they are named, so one of them runs.
        plugin == "kinsol" && @test all_agree(evaluated(native(f; solvers), f, values), mx_casadi(f, values); rtol = 1e-7)
    end
end

@testset "reverse mode and derivatives of the second order through a replaced integrator" begin
    x, p = MX.sym("x", 2), MX.sym("p")
    fixed = C.integrator("fixed", "rk", Dict("x" => x, "p" => p, "ode" => -p * x), 0.0, 1.0)
    f = CasADiCodegen.Function("f", [x, p], [C.gradient(C.sumsqr(fixed(x, MX(0, 1), p, MX(0, 1), MX(), MX(), MX())[1]), p)])
    values = [[0.4, -0.3], [1.7]]
    exact = [-2 * 0.25 * exp(-3.4)]
    named = evaluated(native(f; solvers = Solvers(overrides = (Solver(fixed, Vern9(); abstol = 1e-13, reltol = 1e-13, specialize = SciMLBase.AutoSpecialize),))), f, values)
    @test named[1] ≈ exact rtol = 1e-10
    # The Hessian through an integrator with a variable step: CasADi asks for the forward derivative of the adjoint sensitivities.
    free = C.integrator("free", "cvodes", Dict("x" => x, "p" => p, "ode" => -p * x), 0.0, 1.0)
    cost = C.sumsqr(free(x, MX(0, 1), p, MX(0, 1), MX(), MX(), MX())[1])
    f = CasADiCodegen.Function("f", [x, p], [C.gradient(cost, p), C.densify(CasADiCodegen.hessian(cost, C.vertcat([x, p])))])
    slope, curve = evaluated(native(f; solvers = Solvers(ode = PRECISE)), f, values)
    decay = exp(-3.4)
    @test slope ≈ exact rtol = 1e-10
    @test reshape(curve, 3, 3) ≈ [2decay 0 -1.6decay; 0 2decay 1.2decay; -1.6decay 1.2decay 4 * 0.25 * decay] rtol = 1e-8 atol = 1e-12
end

@testset "integrator of CasADi with an event function" begin
    x, e, g = MX.sym("x", 2), MX.sym("e"), MX.sym("g")
    dae = Dict("x" => x, "p" => e, "u" => g, "ode" => C.vertcat([x[2], -g]), "quad" => x[2]^2, "zero" => x[1])
    transition = C.Function("transition", Dict("x" => x, "p" => e, "post_x" => C.vertcat([x[1], -e * x[2]])), C.event_in(), C.event_out())
    times = [0.6, 1.4, 2.5]
    ball = C.integrator("ball", "cvodes", dae, 0.0, times, Dict("transition" => transition))
    p, u = MX.sym("p"), MX.sym("u", 1, 3)
    results = ball(x, MX(0, 1), p, u, MX(), MX(), MX())
    final, quadrature = C.vec(results[1]), C.vec(results[3])
    # CasADi gives the Jacobian of an integrator with events the sparsity pattern of the model without them, so the
    # Jacobian is that of directional derivatives, one per argument.
    arguments = C.vertcat([x, p, C.vec(u)])
    slopes = C.jtimes(C.vertcat([final, quadrature]), arguments, MX(C.DM([Float64(i == j) for i in 1:6, j in 1:6])))
    f = CasADiCodegen.Function("f", [x, p, u], [final, quadrature, C.densify(slopes)])
    # Four impacts, two of them in the last interval.
    values = [[1.5, 2.0], [0.8], [9.81, 5.0, 12.0]]
    J = ForwardDiff.jacobian(v -> reduce(vcat, ball_reference(v[1:2], v[3], v[4:6], times)), reduce(vcat, values))
    expected = [ball_reference(values[1], values[2][1], values[3], times)..., vec(J)]
    solvers = Solvers(ode = PRECISE)
    @test_throws "CasADiCodegen.Solvers(ode = ...)" K.algorithm(f; expand = false)
    # The Jacobian is that of the forward sensitivities, whose states jump at each impact.
    @test all_agree(evaluated(native(f; solvers), f, values), expected; rtol = 1e-8)
    plain = CasADiCodegen.Function("plain", [x, p, u], [final])
    @testset "a written module has the solver" begin
        text = sprint(io -> generate_julia(plain, io; module_name = :Written, name = :run!, expand = false, solvers))
        src = Module()
        Base.include_string(src, text)
        written = Base.invokelatest((r, a) -> src.Written.run_nonzeros!(r, a), [fill(NaN, 6)], Tuple(values))
        @test all_agree(written, expected[1:1]; rtol = 1e-9)
    end
    # As the integrator of CasADi, a call stops after `max_events` events, 20 by default: an elastic ball under a strong
    # gravity hits the ground about 30 times.
    @test_throws "more than 20 events" evaluated(native(plain; solvers), plain, [values[1], [1.0], fill(2000.0, 3)])
    # A fixed step has no Julia code with events: only an override replaces it.
    fixed = C.integrator("fixed", "rk", dae, 0.0, times, Dict("transition" => transition))
    k = CasADiCodegen.Function("k", [x, p, u], [fixed(x, MX(0, 1), p, u, MX(), MX(), MX())[1]])
    @test_throws "overrides = [CasADiCodegen.Solver(I, alg)]" K.algorithm(k; expand = false, solvers)
    named = evaluated(native(k; solvers = Solvers(overrides = (Solver(fixed, Vern9(); abstol = 1e-13, reltol = 1e-13, specialize = SciMLBase.AutoSpecialize),))), k, values)
    @test all_agree(named, expected[1:1]; rtol = 1e-9)
end

# Algebraic states: the state z = p x1 makes x1' = -z a decay with the rate p, and x2 is the integral of x1.
const DAE_SOLVER = Solver(Rodas5P(); abstol = 1e-11, reltol = 1e-11, specialize = SciMLBase.AutoSpecialize)
dae_exact(x0, rate) = (final = x0[1] * exp(-rate); [final, x0[2] + x0[1] * (1 - exp(-rate)) / rate, rate * final])

@testset "integrator of this package with algebraic states" begin
    y, p = MX.sym("y", 3), MX.sym("p")
    model = Dict("x" => y, "p" => p, "ode" => C.vertcat([-y[3], y[1], y[3] - p * y[1]]))
    rule = CasADiCodegen.integrator("stiff", Rodas5P(), model, 0.0, 1.0; mass = [1.0, 1.0, 0.0], abstol = 1e-11, reltol = 1e-11, specialize = SciMLBase.AutoSpecialize)
    f = CasADiCodegen.Function("f", [y, p], [rule(y, p), C.jacobian(rule(y, p), y), C.jacobian(rule(y, p), p)])
    g = native(f)
    by_rate = ForwardDiff.derivative(r -> dae_exact([0.4, -0.3], r), 1.7)
    by_state = ForwardDiff.jacobian(v -> dae_exact(v, 1.7), [0.4, -0.3])
    # The third initial value is a guess of the algebraic state: the result does not depend on it.
    for guess in (0.68, 0.0)
        final, J, P = evaluated(g, f, [[0.4, -0.3, guess], [1.7]])
        @test final ≈ dae_exact([0.4, -0.3], 1.7) rtol = 1e-8
        @test reshape(J, 3, 3) ≈ [by_state zeros(3)] rtol = 1e-7 atol = 1e-9
        @test P ≈ by_rate rtol = 1e-7
    end
    @test_throws "one number per state" CasADiCodegen.integrator("stiff", Rodas5P(), model, 0.0, 1.0; mass = [1.0, 0.0])
    # The adjoint equations give the gradient of a weighted sum of the final state, the algebraic state included.
    @testset "adjoint equations" begin
        backward = CasADiCodegen.integrator("stiff_a", Rodas5P(), model, 0.0, 1.0; mass = [1.0, 1.0, 0.0], adjoint = true, abstol = 1e-11, reltol = 1e-11, specialize = SciMLBase.AutoSpecialize)
        weights = [0.7, -1.3, 2.1]
        h = CasADiCodegen.Function("h", [y, p], [C.gradient(C.dot(MX(C.DM(weights)), backward(y, p)), C.vertcat([y, p]))])
        gradient = evaluated(native(h), h, [[0.4, -0.3, 0.2], [1.7]])[1]
        # The guess of the algebraic state has no effect on the result.
        @test gradient ≈ [by_state' * weights; 0.0; sum(by_rate .* weights)] rtol = 1e-7 atol = 1e-9
        # With free times the gradient by the final time is the rate of the weighted sum, and that by the initial time its opposite.
        free = CasADiCodegen.integrator("stiff_f", Rodas5P(), model; mass = [1.0, 1.0, 0.0], adjoint = true, abstol = 1e-11, reltol = 1e-11, specialize = SciMLBase.AutoSpecialize)
        ta, tb = MX.sym("ta"), MX.sym("tb")
        k = CasADiCodegen.Function("k", [y, p, ta, tb], [C.gradient(C.dot(MX(C.DM(weights)), free(y, p, ta, tb)), C.vertcat([ta, tb]))])
        final = dae_exact([0.4, -0.3], 1.7)
        rate = sum([-final[3], final[1], -1.7 * final[3]] .* weights)
        @test evaluated(native(k), k, [[0.4, -0.3, 0.2], [1.7], [0.5], [1.5]])[1] ≈ [-rate, rate] rtol = 1e-7
        # Forward over reverse: the Hessian by the parameter differentiates the adjoint integrator.
        curve = CasADiCodegen.Function("curve", [y, p], [C.hessian(C.dot(MX(C.DM(weights)), backward(y, p)), p)[1]])
        bend = ForwardDiff.derivative(r -> ForwardDiff.derivative(s -> sum(dae_exact([0.4, -0.3], s) .* weights), r), 1.7)
        @test evaluated(native(curve), curve, [[0.4, -0.3, 0.2], [1.7]])[1] ≈ [bend] rtol = 1e-6
    end
    # An algebraic equation with no solution, z^2 + 1 = 0: the Newton method stops after its 50 steps.
    never = K.RightSide((res, arg) -> (res[1][1] = -arg[1][1]; res[1][2] = arg[1][2]^2 + 1; nothing), [1.0, 0.0], (res, arg) -> (res[1][1] = 2 * arg[1][2]; nothing))
    @test_throws "the algebraic equations of the model have no consistent initial values near the guess" K.consistent!([1.0, 0.3], never, Float64[], 0.0)
    # With free times the derivative of an algebraic state by the final time comes from the algebraic equation, not from its residual.
    arc = CasADiCodegen.integrator("stiff", Rodas5P(), model; mass = [1.0, 1.0, 0.0], abstol = 1e-11, reltol = 1e-11, specialize = SciMLBase.AutoSpecialize)
    t0, tf = MX.sym("t0"), MX.sym("tf")
    m = CasADiCodegen.Function("m", [y, p, t0, tf], [C.jacobian(arc(y, p, t0, tf), C.vertcat([y, t0, tf]))])
    final = dae_exact([0.4, -0.3], 1.7)
    rate = [-final[3], final[1], -1.7 * final[3]]
    @test reshape(evaluated(native(m), m, [[0.4, -0.3, 0.2], [1.7], [0.5], [1.5]])[1], 3, 5) ≈ [by_state zeros(3) -rate rate] rtol = 1e-7 atol = 1e-9
end

@testset "integrator of CasADi with algebraic states" begin
    x, z, p = MX.sym("x", 2), MX.sym("z"), MX.sym("p")
    rule = C.integrator("rule", "idas", Dict("x" => x, "z" => z, "p" => p, "ode" => C.vertcat([-z, x[1]]), "alg" => z - p * x[1], "quad" => z), 0.0, [0.5, 1.0])
    results = rule(x, z, p, MX(0, 1), MX(), MX(), MX())
    f = CasADiCodegen.Function("f", [x, z, p], [results[1], results[2], results[3], C.jacobian(results[1][:, 2], p), C.jacobian(results[2][:, 2], x)])
    solvers = Solvers(dae = DAE_SOLVER)
    @test_throws "function \"rule\" is the integrator \"idas\" of CasADi" K.algorithm(f; expand = false)
    values = [[0.4, -0.3], [0.1], [1.7]]
    half = dae_exact([0.4, -0.3], 1.7 * 0.5) .* [1, 1, 2]       # the state at the time 0.5: a decay over half the time
    half[2] = -0.3 + 0.4 * (1 - exp(-0.85)) / 1.7
    full = dae_exact([0.4, -0.3], 1.7)
    by_rate = ForwardDiff.derivative(r -> dae_exact([0.4, -0.3], r), 1.7)
    by_state = ForwardDiff.jacobian(v -> dae_exact(v, 1.7), [0.4, -0.3])
    expected = [[half[1:2]; full[1:2]], [half[3], full[3]], [0.4 - half[1], 0.4 - full[1]], by_rate[1:2], by_state[3, 1:1]]       # CasADi knows that the algebraic state does not depend on the second state
    g = native(f; solvers)
    @test all_agree(evaluated(g, f, values), expected; rtol = 1e-7)
    # Reverse mode: the gradient by the parameter of one number of the states, the algebraic state and the quadrature.
    h = CasADiCodegen.Function("h", [x, z, p], [C.gradient(C.sumsqr(results[1][:, 2]) + results[2][2] + results[3][2], p)])
    @test evaluated(native(h; solvers), h, values)[1] ≈ [2 * full[1] * by_rate[1] + 2 * full[2] * by_rate[2] + by_rate[3] - by_rate[1]] rtol = 1e-7
    # The solver for ordinary differential equations is not that of a model with algebraic states.
    @test_throws "give one with the option solvers = CasADiCodegen.Solvers(dae = ...)" K.algorithm(f; expand = false, solvers = Solvers(ode = PRECISE))
    # An event: the decay x' = -z with z = p x doubles x when it falls to 0.5, so that the algebraic state follows the jump.
    y, r = MX.sym("y"), MX.sym("r")
    doubling = C.Function("transition", Dict("x" => y, "post_x" => 2y), C.event_in(), C.event_out())
    refill = C.integrator("refill", "idas", Dict("x" => y, "z" => z, "p" => r, "ode" => -z, "alg" => z - r * y, "zero" => y - 0.5), 0.0, [0.4, 1.0, 1.6],
                          Dict("transition" => doubling))
    after = refill(y, z, r, MX(0, 1), MX(), MX(), MX())
    k = CasADiCodegen.Function("k", [y, z, r], [after[1], after[2]])
    period = log(2) / 1.1                     # the time from 1 to 0.5, after which each event starts again from 1
    states = [exp(-1.1 * 0.4), exp(-1.1 * (1.0 - period)), exp(-1.1 * (1.6 - 2period))]
    @test all_agree(evaluated(native(k; solvers), k, [[1.0], [0.0], [1.1]]), [states, 1.1 * states]; rtol = 1e-7)
    slope = CasADiCodegen.Function("slope", [y, z, r], [C.jtimes(after[1], r, MX(1.0))])
    @test_throws "the derivatives of an integrator with algebraic states and an event function are not supported" K.algorithm(slope; expand = false, solvers)
end
