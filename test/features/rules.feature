Feature: CasADi functions with rules for automatic differentiation
  A user who differentiates Julia code with a package that reads the rules of
  ChainRulesCore.jl wants a CasADi function inside that code to give the
  derivatives that CasADi generates.

  Background:
    Given a CasADi function and ChainRulesCore.jl loaded

  Scenario: Differentiable function
    When the user calls CasADiCodegen.differentiable(f)
    Then the result is a Julia function that takes one array per input and returns one array per output
    And its values are those of the out-of-place function of build_function

  Scenario: Forward rule
    When a package calls frule with one change per argument
    Then the result holds the values and the products of the Jacobians of CasADi with the changes
    And an argument without a change adds nothing

  Scenario: Reverse rule
    When a package calls rrule and then the pullback with one seed per result
    Then the pullback returns, for each argument, the sum of the products of the transposed Jacobians with the seeds
    And a result without a seed adds nothing

  Scenario: Code made on demand
    Then the code of each rule is made at its first use and used again afterward
    But a kind of product other than :pushforward and :pullback gives an ArgumentError
