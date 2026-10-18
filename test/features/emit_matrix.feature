Feature: Emit Julia code from a CasADi matrix (MX) function without expansion
  A user builds a large model from CasADi functions that call each other and
  wants Julia code that keeps this hierarchy, so that each function is
  compiled once and the compile time stays low.

  Background:
    Given a CasADi matrix (MX) function "top" that calls a scalar function "h" twice
    And a matrix function "m" that "top" calls and that calls "h" also

  Scenario: Keep the function hierarchy
    When the user calls build_function(top; expand = false)
    Then the result defines "h" once, "m" once and the entry point "top!" last
    And "top!(res, arg)" writes the same output nonzeros as CasADi evaluates

  Scenario: Expansion stays the default
    When the user calls build_function(top)
    Then CasADi expands "top" to one scalar function, as in earlier versions

  Scenario: Function that CasADi cannot expand
    Given a matrix function with a node that has no scalar form
    When the user calls build_function with the default keywords
    Then the matrix emitter is used with no further keyword

  Scenario: Map of a function
    Given a matrix function that applies a function to each column with map
    When the user emits Julia code without expansion
    Then the body is one Julia function that the code calls once per column
    And the values and the derivatives equal the CasADi evaluation, also for a map inside a map

  Scenario: Branches that run only when they are selected
    Given a matrix function with if_else or conditional and short_circuit
    When the user emits Julia code without expansion
    Then the code runs the branch that the integer part of the selector names, and the default for any other value
    And the values and the derivatives equal the CasADi evaluation
    And a Julia function in a branch that is not selected does not run

  Scenario: Linear algebra without expansion
    Given a matrix function with a product, a norm, a determinant, a linear solve, a Kronecker product or logsumexp
    When the user generates matrix code
    Then the code loops over the nonzeros of the operands, in the order of the CasADi runtime
    And the results agree with CasADi for dense and for sparse operands

  Scenario: Large sparse linear system
    Given a linear solve with a sparse matrix of 8 rows or more whose QR factors have few nonzeros
    When the user generates matrix code
    Then the code uses the sparse QR factorization of CasADi
    And the solution agrees with CasADi to rounding error, for the matrix and for its transpose

  Scenario: Indices that are values of the model
    Given a matrix function that reads, writes or adds to nonzeros at indices that are values
    Or that looks for the interval of a value in a grid, as a linear interpolant with inline does
    When the user generates matrix code
    Then the code is ordinary Julia code and the results equal those of CasADi
    And a sum to the nonzeros at a fixed slice plus indices, which CasADi evaluates wrongly, equals the same sum with each index written out

  Scenario: Monitor
    Given a matrix function with a monitor node
    When the generated code runs
    Then it prints the text of the node and the values of its operand, and passes the values on

  Scenario: Function or node of CasADi without instructions
    Given a call of an interpolant, of the Newton rootfinder or of an integrator with a fixed step of CasADi, or a node such as a B-spline
    When the user generates code
    Then the generated code does not call CasADi and the results equal those of CasADi
    And the generated code takes dual numbers

  Scenario: Function with no Julia code
    Given a call of an integrator of CasADi with a variable step, or of a solver of nlpsol or of conic
    When the user generates code with no solver of the SciML ecosystem for it
    Then an ArgumentError names the function and says what the user can do (see solvers.feature)
    And a matrix 2-norm, which CasADi cannot evaluate, gives an ArgumentError that names the function and the operation

  Scenario: All output forms
    When the user asks for an Expr, a runtime generated function and a source file
    Then the three forms give the same numbers, also when the code is split
    And the source file runs in a Julia process that never loads CasADi

  Scenario: One work vector
    When the emitted entry point runs
    Then it uses one work vector of the task, which the called functions share
    And tasks that run the code at the same time, whole or split, do not share a work vector

  Scenario: Julia function in the graph
    Given a Julia function declared with callback(f, name, sizes_in, sizes_out)
    And a CasADi function that calls it
    When the user emits Julia code
    Then the generated code calls the Julia function directly, with no CasADi in between
    And the result equals the CasADi evaluation

  Scenario: Scalar code around Julia functions
    Given a CasADi function whose graph calls Julia functions at its top level
    When the user emits Julia code with the default options
    Then the operations before, between and after the calls are scalar code in one function
    And each Julia function gets static arrays and its own errors and bounds checks stay
    And a call whose results no output needs is left out
    And the in-place form and the form with static arrays allocate no memory
    But with expand = false, or when the code must be split, the code is matrix code

  Scenario: Derivative of a Julia function
    Given a callback declared with jacobian = a Julia function or an ADTypes backend
    When CasADi differentiates a graph that calls it
    Then the Jacobian in the graph is a call to that Julia function or to that backend
    And the generated code calls it directly

  Scenario: Derivatives of higher order of a Julia function
    Given a callback declared with jacobian = a tuple of Julia functions
    When CasADi differentiates the graph once more for each function
    Then each derivative in the graph is a call to the next function of the tuple
    And a block of a derivative by an input that is not an argument is a structural zero
    And one more derivative than the tuple has functions is an error of CasADi

  Scenario: No allocation in matrix code
    When the in-place function or the out-of-place function with static arrays runs matrix code
    Then each called function and sub-function takes the work vector only
    And the call allocates no memory

  Scenario: Julia function in a source file
    Given a callback made from a named function of a module
    When the user calls generate_julia
    Then the file calls the function by its full name
    But a callback made from an anonymous function is rejected with an ArgumentError
