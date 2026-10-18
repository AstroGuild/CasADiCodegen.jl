Feature: Cache of generated code on disk
  A user whose model takes many seconds to compile wants to pay that time
  once, and not in each Julia session.

  Scenario: First use
    Given a CasADi function and a cache directory
    When the user calls build_function with expression = Val{false} and cache
    Then the directory holds one package with the generated module and precompile statements
    And the functions hold compiled code for Float64 arrays before their first call
    And they give the values of the functions without cache and allocate no memory in place

  Scenario: Same model again
    When the user calls build_function again with the same function and options
    Then the result is the same functions and no package is written
    And a new Julia process with the same model finds the package and compiles nothing

  Scenario: Other options
    When the options change the generated code or the compiled forms
    Then another package is written
    And with force_SA the out-of-place function is compiled for static arrays
    And with nonzeros the function on vectors of nonzeros is compiled

  Scenario: Julia function in the graph
    Given a callback made from a named function of a package
    Then the cached package depends on that package
    But a function of Main or an anonymous function is rejected with an ArgumentError

  Scenario: Integrator in the graph
    Given a function that calls an integrator of a SciML solver package
    Then the cached package depends on the package of the algorithm
    And it holds compiled code of the solver for Float64 before the first call
    And the functions give the values of the functions without cache

  Scenario: Wrong use
    When the user asks for a cache with expression = Val{true}
    Then the call fails with an ArgumentError and no package is written
