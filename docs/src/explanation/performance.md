# Cost of the generated code

A generated function costs time twice: Julia compiles it at its first call, and each
later call runs the compiled code. The first cost grows with the size of the model,
so that it dominates for large models, while the second depends on the form of the
code and on the arrays that a call receives. This page gives the measurements on
which the defaults of the package rest; the conditions of the measurements are in
[Reproducibility](@ref).

## Scalar code and its forms

An instruction is one operation of the function, as CasADi counts them: a scalar
operation in an SX function, and an operation of the MX graph, such as a matrix
product or a call, in an MX function.
*Scalar code* is the code of an SX function, or of an MX function that the package
expands to scalar operations; *matrix code* keeps the matrix operations of an MX
function (see [Matrix code and functions without instructions](@ref)). Scalar code
allocates no memory in the in-place form and in the out-of-place form with static
arrays, whatever its size. The table gives the cost of the forms of the tutorial for
two scalar models, each with its 6 by 6 Jacobian, measured once on Julia 1.13:

| Instructions | Form | First call | Later calls | Memory per call |
|---|---|---|---|---|
| 5,361 | Out of place, static arrays | 0.62 s | 1.1 µs | 0 B |
| 5,361 | In place, arrays | 1.04 s | 1.2 µs | 0 B |
| 5,361 | Out of place, arrays | 0.68 s | 1.2 µs | 576 B |
| 18,861 | Out of place, static arrays | 3.69 s | 3.8 µs | 0 B |
| 18,861 | In place, arrays | 6.24 s | 3.9 µs | 0 B |
| 18,861 | Out of place, arrays | 3.82 s | 4.1 µs | 576 B |

The first call is mostly compilation. For scalar code above about 50,000 instructions,
or matrix code above about 1,000, see [Large functions and the cache on disk](@ref).

## Split of a large function

Above `split_above` instructions, `build_function` and `generate_julia` split the code
into sub-functions of at most `chunk_size` instructions (see
[Large functions and the cache on disk](@ref)). The defaults of both keywords come
from the time of the first call, which is mostly compilation, and from the time of
the later calls, measured once on Julia 1.13 for the function on nonzeros of two
models with their dense Jacobians. The chain of maps is a function
that applies a `map` of CasADi to the result of the one before it; the gravity model
is the acceleration of 40 bodies that attract each other.

| Model | Instructions | Sub-function size | First call | Later calls |
|---|---|---|---|---|
| Chain of maps, 6 states | 67,236 | One function | 35 s | 21 µs |
| Chain of maps, 6 states | 67,236 | 500 | 14 s | 28 µs |
| Chain of maps, 6 states | 67,236 | 1,000 | 15 s | 27 µs |
| Chain of maps, 6 states | 67,236 | 5,000 | 26 s | 28 µs |
| Chain of maps, 6 states | 67,236 | 20,000 | 34 s | 25 µs |
| Gravity of 40 bodies | 102,946 | One function | 54 s | 70 µs |
| Gravity of 40 bodies | 102,946 | 500 | 39 s | 97 µs |
| Gravity of 40 bodies | 102,946 | 1,000 | 53 s | 96 µs |
| Gravity of 40 bodies | 102,946 | 5,000 | 63 s | 98 µs |
| Chain of maps, 6 states | 224,736 | One function | 339 s | 89 µs |
| Chain of maps, 6 states | 224,736 | 1,000 | 54 s | 105 µs |
| Chain of maps, 6 states | 224,736 | 5,000 | 92 s | 102 µs |
| Chain of maps, 6 states | 224,736 | 20,000 | 186 s | 102 µs |

Once a function is split, the size of the sub-functions has almost no effect on the
later calls, while the first call becomes slower as the size grows. Where the size
500 was measured, it gives the shortest first call: 14 s against 15 s at the default
1,000 for the chain of 67,236 instructions, and 39 s against 53 s for the gravity
model. The split itself makes the later calls 15 to 40 percent slower, from 89 µs to
102–105 µs for the largest chain and from 70 µs to 96–98 µs for the gravity model.
Whether it shortens the first call depends on the model: the largest chain compiles in
54 s instead of 339 s, but the gravity model gains nothing at the default size (53 s
against 54 s). For two smaller versions of these models, near the default limit of
50,000 instructions and not in the table, the first call of one function took 18 s for
the chain and 14 s for the gravity model, against 10 s and 22 s when split.
