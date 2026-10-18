# [Stop at an event](@id events)

This page continues [Integrate a differential equation](@ref) and uses its model
`x`, `mu`, `ode` and its symbols `x0`, `p`, `t0`, `tf`.

## Find one event

With free times, an entry `"zero"` holds an event function of the state, the
parameters and the time, and the integration ends at the event: the first time
`te` between the initial time and `tf` at which the event function changes its
sign. The function then returns the state at the event, the quadratures if the
model has them, and `te`. A zero at the initial time is not an event, so that an
integration can start on the surface, and a call with no event before `tf` throws. The
example gives the time from one apsis of an orbit to the next one, where the
radial speed is zero.

```julia
apsis = integrator("apsis", Vern9(), Dict("x" => x, "p" => mu, "ode" => ode, "zero" => x[1] * x[3] + x[2] * x[4]);
                   abstol = 1e-12, reltol = 1e-12)
xe, te = apsis(x0, p, t0, tf)
f = CasADiNative.Function("f", [x0, p, t0, tf], [xe, te, jacobian(xe, x0), jacobian(te, x0)])
```

Each call runs two integrations: one that finds the event and one to the event time,
with the sensitivities when a result needs a derivative. CasADi differentiates the
event time by the implicit function theorem, as the root of the event function, and
the state at the event as the result of an integrator with free times, both to any
order.

The keyword `direction` selects the change of sign (1 from negative to positive, -1 the
opposite, 0 both), and `interp_points` is the number of points of each step at which
the solver looks for the change, besides the end of the step: the default of 10 is
that of SciML, and 0 is faster but can miss two changes of sign in one step. With
`specialize = SciMLBase.AutoSpecialize` (after `import SciMLBase`) the solver also compiles once for all event
functions. For the orbit above, measured once:

| Outputs | `interp_points = 10` | `interp_points = 0` |
|---|---|---|
| State at the event and event time | 91 µs | 50 µs |
| The above with their Jacobians by the initial state | 99 µs | 61 µs |
| An arc to a given time with its Jacobian, for comparison | 35 µs | 35 µs |

## Pass several events

One integrator can also pass several events. The keyword `events` gives their
number, and `te` is then the vector of their times; the entry `"transition"` of the
dictionary gives the state after an event as an expression of the state before it,
the parameters and the time, which is how a model applies an impulse or a bounce.
With `terminal = false` the integration does not end at the last event: it applies
the transition there too and continues to `tf`, so that the result is the state at
the final time. CasADi differentiates the result through each event to any order.

The example is a ball that falls and bounces three times. Its state is the height
and the speed, and its parameters are the gravity and the part of the speed that a
bounce keeps.

```julia
s, c = MX.sym("s", 2), MX.sym("c", 2)                    # s = [height, speed], c = [gravity, restitution]
ball = Dict("x" => s, "p" => c, "ode" => vertcat(s[2], -c[1]), "zero" => s[1],
            "transition" => vertcat(s[1], -c[2] * s[2]))  # the speed changes its sign and loses a part
bounce = integrator("bounce", Vern9(), ball; events = 3, terminal = false, direction = -1)

s0, c0 = MX.sym("s0", 2), MX.sym("c0", 2)
sf, te = bounce(s0, c0, t0, tf)                           # te has the three times of contact
```

An integrator of CasADi with an event function and the option `"transition"` has
its own rules; generated code replaces it as [Integrators with events](@ref) shows.
