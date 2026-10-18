Feature: Integrate an ordinary differential equation inside a CasADi graph
  A user who writes a model with CasADi wants the solvers of the SciML
  ecosystem to integrate it, with exact derivatives, in the CasADi graph and
  in the generated Julia code.

  Background:
    Given a dictionary with the state "x", the right side "ode" and, if the model has them, the parameters "p" and the time "t"
    And an ODE algorithm of a SciML solver package, such as Vern9()

  Scenario: Integrator as a CasADi function
    When the user calls integrator(name, algorithm, dae, t0, tf)
    Then the result is a CasADi function from the initial state and the parameters to the final state
    And its value agrees with the CasADi integrator cvodes within the tolerances

  Scenario: Derivatives of any order
    When CasADi differentiates a graph that calls the integrator
    Then the Jacobian is a call to a second integrator for the state with its sensitivity matrices
    And that integrator is built only when CasADi asks for the derivative
    And the first and second derivatives agree with cvodes within the tolerances
    And the integrator of each order takes the initial state and the parameters of the first one
    And it integrates the derivatives by those only: 4 states and 1 parameter give 24 states, then 144

  Scenario: Generated code
    When the user calls build_function on a function that calls the integrator
    Then the generated code calls the solver directly, with no CasADi in between
    And it gives the same numbers as the CasADi evaluation
    And later calls reuse the state of the solver, so that they allocate little memory
    And calls from different tasks do not share that state

  Scenario: Final state together with its Jacobian
    Given a function whose outputs are the final state and its Jacobian
    When the generated code runs
    Then the call for the state runs the integration with the sensitivities and keeps its result
    And the call for the Jacobian takes that result, so the solver of the state alone does not run
    And the state agrees with an integration of the state alone within the tolerances
    And this holds for scalar code around the calls and for matrix code
    But a function with the state alone runs the integration of the state
    And a run that fails keeps no result

  Scenario: Arcs in a map
    Given a map of an integrator over the columns of the initial states, with its Jacobian
    When the generated code runs
    Then each arc is integrated once, with its sensitivities
    And the values agree with the CasADi evaluation

  Scenario: Free initial and final times
    When the user calls integrator without the two times
    Then the function takes the initial state, the parameters if there are any, the initial time and the final time
    And it equals the integrator with fixed times for the same times
    And CasADi differentiates it by the two times, to any order
    And the final time can be before the initial time, or equal to it, which gives the initial state
    And a map gives each arc its own times

  Scenario: States on a grid of times
    When the user gives a vector of times in place of the final time
    Then the function returns a matrix whose column k is the state at time k
    And each column agrees with the integrator with fixed times to that time
    And CasADi differentiates each column
    But an empty vector or a time that is not finite gives an ArgumentError

  Scenario: Quadratures
    Given a dictionary with the entry "quad"
    When the user makes an integrator with fixed times, with free times or with a grid of times
    Then the function returns the final state and the integrals of the quadratures from the initial time
    And CasADi differentiates the integrals by the initial state, the parameters and the times

  Scenario: Event that ends the integration
    Given a dictionary with the entry "zero", an event function of the state, the parameters and the time
    When the user makes an integrator with free times
    Then the function returns the state at the first change of sign of the event function, and the time of it
    And CasADi differentiates the event time and the state at the event to any order
    And the generated code integrates the sensitivities once
    And a zero of the event function at the initial time is not an event
    And direction selects the change of sign, and interp_points how often the solver looks for it
    But a call with no event before the final time throws an error that names the integrator
    And fixed times, a grid of times or an event function that is not a scalar give an ArgumentError

  Scenario: Several events, with a transition of the state
    Given a dictionary with the entries "zero" and "transition", the state after an event
    When the user makes an integrator with events = n
    Then the function returns the vector of the n event times
    And the state after each event that the integration passes is that of the transition
    And with terminal = false the integration applies the transition at the last event and goes on to the final time
    And CasADi differentiates the results through each event
    But events or terminal without an event function give an ArgumentError

  Scenario: Dual numbers through an event
    When dual numbers pass through the generated code of an integrator with an event
    Then the derivatives of the event time are those of the implicit function theorem

  Scenario: Adjoint sensitivities
    When the user gives adjoint = true
    Then a reverse derivative comes from an integrator of the adjoint equations, which runs backward in time
    And the gradient agrees with that of the forward sensitivities within the tolerances
    And derivatives of higher order agree too
    And a reverse derivative through an event agrees with the exact solution

  Scenario: One compilation of the solver for all integrators
    When the user gives specialize = SciMLBase.AutoSpecialize
    Then the solver calls the right side through a function wrapper
    And the results agree with those of the default

  Scenario: Solver options
    When the user gives keywords such as abstol, reltol or maxiters
    Then the solver receives them

  Scenario: Solver failure
    Given a problem that the solver cannot integrate to the final time
    When the generated code runs
    Then it throws an error that names the integrator and the return code of the solver

  Scenario: Limits
    When the dictionary has an entry other than "x", "p", "t", "ode", "quad" and "zero"
    Or the right side does not have the size of the state
    Then the call is rejected with an ArgumentError

  Scenario: Integrator in a source file
    When the user calls generate_julia on a function that calls the integrator
    Then the module loads the package of the algorithm and makes the solver with its options
    And the function of the module gives the values of the runtime generated function
    But a solver made by hand from a local function is rejected with an ArgumentError
