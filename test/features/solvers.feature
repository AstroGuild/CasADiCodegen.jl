Feature: Solver objects of CasADi with solvers of the SciML ecosystem
  A model can hold an integrator, a rootfinder or an optimization solver of
  CasADi. The package reads the problem of such an object, so that a solver of
  the SciML ecosystem solves it: as a SciML problem of the user, or in place of
  the solver of CasADi in generated code, which never calls CasADi.

  Scenario: Problem of an integrator
    Given an integrator of CasADi with the method cvodes, idas, rk or collocation
    When the user calls SciMLBase.ODEProblem(I, x0, p; z0, u)
    Then the problem has the equations of the integrator with generated code, its time span and its output times
    And the tolerances of cvodes and idas, and a mass matrix when the model has algebraic states
    And controls on several intervals change at the output times by a callback of the problem
    And an event function gives a callback that applies the transition of the integrator

  Scenario: Problem of a rootfinder
    Given a rootfinder of CasADi with the method newton, fast_newton or kinsol
    When the user calls SciMLBase.NonlinearProblem(R, z0, others...)
    Then a SciML solver finds the root that CasADi finds

  Scenario: Problem of an optimization solver
    Given a solver that nlpsol of CasADi made
    When the user calls SciMLBase.OptimizationProblem(S, x0, p; lbx, ubx, lbg, ubg)
    Then the problem has the objective, the constraints, their derivatives and the bounds, with the default bounds of CasADi
    And a solver of Optimization.jl finds the solution

  Scenario: Selection of solvers
    Given CasADiCodegen.Solvers with the fields ode, dae, nonlinear and optimization, and overrides
    When the user gives an algorithm, or CasADiCodegen.Solver(alg; options...)
    Then a solver with a function of CasADi is accepted in overrides only, where it is necessary

  Scenario: Integrator with a variable step in generated code
    Given a graph that calls an integrator cvodes with output times, controls and a quadrature
    When the user builds the code with solvers = CasADiCodegen.Solvers(ode = ...)
    Then the states, the quadratures and their forward derivatives equal those of an independent integration with that solver
    And a written module has the solver
    And the tolerances of the integrator of CasADi are those of the solver when the user gives none
    But without a solver an error names the function and the field ode of CasADiCodegen.Solvers

  Scenario: Integrator with algebraic states in generated code
    Given a graph that calls an integrator idas with an algebraic state
    When the user builds the code with solvers = CasADiCodegen.Solvers(dae = ...)
    Then the states, the algebraic states, the quadratures and their forward derivatives equal the exact solution
    But a solver in the field ode only gives an error that names the field dae

  Scenario: Integrator of this package with algebraic states
    Given a model whose state has a mass of 0 for each algebraic state
    When the user calls CasADiNative.integrator with the keyword mass and an algorithm for a mass matrix
    Then the result and its forward derivatives equal the exact solution, for any guess of the algebraic state
    And the derivatives by free times give the rate of an algebraic state from the algebraic equations
    And with adjoint = true the gradient and the Hessian come from the adjoint equations with the same mass
    But a mass of a wrong size and equations with no solution give errors

  Scenario: One solver for one function
    Given a graph with an integrator rk and an integrator cvodes
    When the user gives an override for the integrator rk
    Then that integrator and its derivatives use the solver, and the other objects use the solvers of the fields
    And without the override the integrator rk keeps the Julia code of the method of CasADi

  Scenario: Rootfinder in generated code
    Given a graph that calls a rootfinder kinsol or fast_newton, with its derivatives
    When the user builds the code with solvers = CasADiCodegen.Solvers(nonlinear = ...)
    Then the results equal those of CasADi
    But without a solver an error names the function and the field nonlinear

  Scenario: Optimization solver in generated code
    Given a graph that calls a solver of nlpsol with parameters and bounds, and derivatives of its results
    When the user builds the code with solvers = CasADiCodegen.Solvers(optimization = ...)
    Then the solution, the objective, the constraints and the multipliers equal the exact ones
    And the multiplier of a bound that is not active is exactly zero
    And the derivatives of the first and the second order equal the exact ones, and a written module has the solver
    But numbers that are not Float64, a solver that fails, and a graph with no solver give errors

  Scenario: Reverse mode through a replaced integrator
    Given a graph with the gradient of a number that depends on the results of an integrator cvodes, idas or rk
    When the user builds the code with a solver for that integrator
    Then the gradient equals that of an independent integration, or the exact one
    And the Hessian, for which CasADi asks for the forward derivative of the adjoint sensitivities, equals the exact one

  Scenario: Solver of quadratic problems
    Given a graph that calls a solver that conic of CasADi made, with no cone constraints
    When the user builds the code with a solver for optimization problems
    Then the solution, the objective and the multipliers equal those of the solver qrqp of CasADi
    And SciMLBase.OptimizationProblem gives the problem, whose parameters are the nonzeros of h, then g, then the nonzeros of a

  Scenario: Integrator of CasADi with an event function
    Given a graph that calls an integrator cvodes or idas with an event function and a transition
    When the user builds the code with a solver for ordinary differential equations or for algebraic states
    Then the states and the quadratures at the output times are those of the exact solution, through each event
    And the directional derivatives through the events are those of the exact solution
    And a call throws after more than max_events events, as in CasADi
    And a written module makes the solver again
    But an integrator rk or collocation with an event function needs an override
    And forward directions with algebraic states give an error
