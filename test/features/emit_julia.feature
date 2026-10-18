Feature: Emit Julia code from a CasADi function
  A user writes a model with CasADi in Julia and wants the same computation
  as plain Julia code that runs without CasADi.

  Background:
    Given a CasADi scalar (SX) function "f" with inputs "x" and "p"

  Scenario: Runtime generated function
    When the user calls build_function(f; expression = Val{false})
    Then the returned object is a RuntimeGeneratedFunction, whatever the size of "f"
    And it is callable as g(res, arg) in the same session
    And it writes the same output nonzeros as CasADi evaluates

  Scenario: Julia source file
    When the user calls generate_julia(f, path) with a module name
    Then the file holds one standalone module
    And a Julia process that never loads CasADi can include the file
    And the function in that module gives the same numbers as the runtime generated function

  Scenario: Julia expression
    When the user calls build_function(f)
    Then the result is an Expr that defines a function named after "f"
    And evaluating it in any module gives a function with the same results

  Scenario: Large function
    Given a function with more instructions than split_above
    When the user emits Julia code
    Then the body is split into sub-functions of at most chunk_size instructions
    And the sub-functions share one work vector, which belongs to the task, so a call does not allocate it
    And the in-place, the out-of-place and the nonzero form share the same sub-functions
    And the results are bit-for-bit the same as for the unsplit form

  Scenario: Limits of the split
    When the user gives neither chunk_size nor split_above
    Then scalar code is one function up to the default limit, and has sub-functions of the default size above it
    And chunk_size alone splits each function with more instructions than chunk_size
    And split_above alone moves the limit and keeps the default size

  Scenario: Generic number type
    When the user calls the generated function with ForwardDiff dual numbers
    Then the derivative agrees with the Jacobian that CasADi computes

  Scenario: Domain errors follow CasADi
    When an operation leaves its domain, such as sqrt of a negative number
    Then the generated code returns NaN, as CasADi does, and does not throw

  Scenario: Domain errors follow Julia on request
    When the user passes nanmath = false
    Then the generated code calls the Base functions, which throw a DomainError
    And the generated code accepts any real number type, such as BigFloat

  Scenario: Wrong argument shape
    When the user passes too few arguments or too short a vector
    Then the generated function throws an ArgumentError before it computes

  Scenario: Unsupported function
    Given a CasADi function with free symbols, or one that CasADi cannot expand to SX
    When the user calls build_function or generate_julia
    Then an ArgumentError names the function
