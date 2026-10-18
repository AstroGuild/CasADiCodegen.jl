Feature: Julia code for the functions and nodes of CasADi that have no instructions
  CasADi does not give the data of these functions and nodes through its
  interface. The package reads the data from the C code that CasADi generates
  and from the serial form of the function, and emits Julia code that does not
  call CasADi.

  Scenario: B-spline node
    Given a B-spline of CasADi with fixed coefficients or with coefficients that are an argument
    When the generated code runs at points in a knot span, at a knot, at both ends and out of the range
    Then the results equal those of CasADi for the lookup modes linear and binary
    And the call allocates no memory

  Scenario: Interpolant
    Given an interpolant of CasADi, linear or bspline, with fixed values or with the values as an argument
    When the generated code runs
    Then the value and its derivative by the point equal those of CasADi
    And the derivative by the values is a structural zero, as in CasADi

  Scenario: Assertion
    Given a value with an assertion
    When the condition is false
    Then the generated code throws an AssertionError with the text of the node

  Scenario: Value written to a file
    Given a value with a dump node
    When the generated code runs twice
    Then it writes two numbered Matrix Market files that equal those of CasADi

  Scenario: Matrix made positive definite
    Given a symmetric matrix, or one triangle of it, with the node convexify
    When the generated code runs with a matrix that has eigenvalues of both signs
    Then the result equals that of CasADi for the strategies regularize, eigen-clip and eigen-reflect
    And eigenvalues that do not converge in the limit of iterations give an error

  Scenario: External function
    Given a function of a compiled library
    When the generated code runs
    Then it calls the library directly and the results equal those of CasADi
    But a number type other than Float64 gives an error that names the function

  Scenario: Newton rootfinder of CasADi
    Given a rootfinder of CasADi with the method newton and its options
    When the generated code runs
    Then the root and its derivatives equal those of CasADi
    And a failure gives an error, or the last iterate when the option error_on_fail is false
    And the option constraints is not read, because the Newton method of CasADi does not use it

  Scenario: Integrator of CasADi with a fixed step
    Given an integrator of CasADi with the method rk or collocation, with output times, controls and a quadrature
    When the generated code runs
    Then the states, the quadratures and their forward and adjoint sensitivities equal those of CasADi
    And the derivatives of the second order, and two adjoint directions at once, equal those of CasADi
    But an integrator with an event function gives an error that names CasADiNative.integrator and its events

  Scenario: Function with no Julia code
    Given a graph that calls a rootfinder of CasADi with the method nlpsol, or a callback of a subtype of CasadiCallback
    When the user builds the code
    Then an error names the function and its class, or says to make the callback with CasADiNative.callback

  Scenario: Written module
    When the user writes a function with such a node or solver to a module
    Then the module gives the results of CasADi and evaluates nothing through CasADi
