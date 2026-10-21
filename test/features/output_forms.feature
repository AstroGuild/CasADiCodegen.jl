Feature: Generated functions in the in-place and the out-of-place form
  A user who calls generated code from Julia wants functions that take and
  return ordinary arrays or static arrays in their matrix shape, in place or
  out of place, as Symbolics.build_function gives them.

  Background:
    Given a CasADi function whose inputs and outputs can have sparse patterns

  Scenario: Pair of functions
    When the user calls build_function(f; expression = Val{false})
    Then the result is the pair of an out-of-place and an in-place runtime generated function
    And with nonzeros = true the result is the single function on vectors of nonzeros

  Scenario: Out of place with ordinary arrays
    When the user calls the out-of-place function with one ordinary array per input
    Then each output is a new Vector for a column and a new Matrix otherwise
    And a function with one output returns the array itself, and with more outputs a tuple
    And each structural zero of an output is zero

  Scenario: In place with ordinary arrays or mutable static arrays
    When the user calls the in-place function with a tuple of outputs and a tuple of inputs
    Then it fills each output in its matrix shape, with zero at each structural zero
    And the outputs can be Vector and Matrix, or MVector and MMatrix

  Scenario: Out of place with static arrays
    When the first argument of the out-of-place function is a static array
    Then each output is an SVector for a column and an SMatrix otherwise
    And with force_SA = true the outputs are static arrays for any argument
    And scalar code does not allocate memory, as one function or split into sub-functions

  Scenario: Sparse matrices in place
    Given SparseArrays is loaded
    When an output or an input of the in-place function is a SparseMatrixCSC with the pattern of the function
    Then the function works on the stored values only and allocates no memory
    And SparseMatrixCSC(sparsity) makes a matrix with the pattern of a CasADi sparsity
    And a sparse matrix with another pattern gives an ArgumentError

  Scenario: Inputs with a sparse pattern
    When an input has structural zeros
    Then the function reads the structural nonzeros from the matrix shape and ignores the other entries

  Scenario: All kinds of generated code
    When the function is expanded, chunked or kept as matrix code
    Then all forms give the values of CasADi
    And generate_julia writes the three functions to the module, which imports StaticArraysCore, and StaticArrays when a Julia function gets static arrays

  Scenario: Optimization level of the compiled functions
    When the user calls build_function(f; expression = Val{false}, optlevel = 1)
    Then Julia compiles the returned functions at optimization level 1
    And they give the same values as with the default level
    And generate_julia(f, io; optlevel = 1) writes a module with that level
    And an optlevel outside 0 to 3, or with an expression, fails with an ArgumentError

  Scenario: Wrong use
    When the name does not end with "!", or an array has the wrong number of elements
    Then the call fails with an ArgumentError
