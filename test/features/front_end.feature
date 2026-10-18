Feature: The front end of CasADi in Julia
  The package adds methods to the front end CasADiNative.jl, so that the numbers
  in a Dict of options reach CasADi with their types.

  Scenario: Numbers in a Dict of options
    Given a function of CasADiNative.C that takes a Dict of options
    When the Dict has an integer, a Float64 with a whole value, a vector of such numbers or a nested Dict
    Then CasADi gets an integer as an integer and any other real number as a double
    And the result is that of the option, such as 7 steps of an integrator rk for number_of_finite_elements = 7
