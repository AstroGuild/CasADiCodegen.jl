Feature: Roots of equations found by a SciML solver
  A user whose model holds an equation with no closed solution wants its root
  inside the CasADi graph, with derivatives, and generated code that calls the
  solver directly.

  Scenario: Root of one equation
    Given a CasADi function f(z, p1, p2, ...) whose result has the size of z
    When the user calls rootfinder(name, alg, f) with a SciML nonlinear algorithm
    Then the result is a CasADi function of a first guess and the other arguments, which returns the root
    And the generated code and the CasADi evaluation give the root within the tolerance

  Scenario: Derivatives
    When CasADi differentiates a graph that calls the rootfinder
    Then the derivative by the first guess is zero
    And the derivatives of first and second order by the parameters agree with the implicit function theorem
    And dual numbers pass through the generated code

  Scenario: System with a matrix parameter
    Given a system of equations with a vector and a matrix as parameters
    Then the root and its Jacobians by both parameters are correct

  Scenario: Rootfinder in a source file
    When the user calls generate_julia on a function that calls the rootfinder
    Then the module loads the package of the algorithm and makes the solver with its options
    And the function of the module gives the values of the runtime generated function

  Scenario: Limits
    When the function has more than one result, a residual of another size than the unknown, or a matrix of unknowns
    Then rootfinder fails with an ArgumentError
    And a solver that finds no root gives an error that names the rootfinder and the return code
