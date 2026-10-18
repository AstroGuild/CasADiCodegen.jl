Feature: CasADi functions as the functions of SciML problems
  A user who solves a problem with a SciML solver wants to give it a model
  written with CasADi, with generated code for the model and for its
  derivatives, so that the solver does not differentiate the model itself.

  Scenario: Ordinary differential equation
    Given a CasADi function f(u), f(u, p) or f(u, p, t) whose result has the size of u
    When the user calls SciMLBase.ODEFunction(f)
    Then the result is an in-place function with the Jacobians by the state and by the parameters
    And a SciML solver integrates the problem to the state that the integrator of this package gives
    And the functions allocate no memory

  Scenario: Nonlinear equations
    Given a CasADi function f(u) or f(u, p) whose result has the size of u
    When the user calls SciMLBase.NonlinearFunction(f)
    Then the result holds the residual and its Jacobian, and a SciML solver finds the root

  Scenario: Optimization
    Given an objective with one number as its result and, optionally, constraints with the same arguments
    When the user calls SciMLBase.OptimizationFunction(objective, constraints)
    Then the result holds the objective, its gradient and Hessian, the constraints and their Jacobian
    And the Hessian of each constraint, from which a solver makes the Hessian of the Lagrange function

  Scenario: Options and limits
    When the user gives jac = false, or other keywords
    Then that Jacobian is absent, and the other keywords go to the SciML constructor
    And a result of another size, too many arguments or constraints with another unknown give an ArgumentError
