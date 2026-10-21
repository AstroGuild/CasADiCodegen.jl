Feature: Trace generic Julia code into a CasADi graph
  A user has a model written as generic Julia code and wants CasADi to
  differentiate it and CasADiCodegen.jl to emit it, without rewriting it.

  Scenario: Generic function on a static vector
    Given a Julia function of a static vector that calls norm
    When the user calls it on traced(x) for a symbolic vector x and untraces the result
    Then the generated value and Jacobian equal those of the Julia function

  Scenario: A branch on a traced value
    When a Julia function takes an if or a ternary on a traced value
    Then the call throws a TypeError instead of following one branch

  Scenario: Choices without a branch
    When the code uses min, max, clamp or ifelse on traced values
    Then the generated code gives the result of each branch at each input

  Scenario: Matrix graph
    Given the result of a callback in an MX graph
    When the user traces it and untraces the result of generic code
    Then the generated value and Jacobian are those of the composed function
