# Reference interpreter: it runs a scalar algorithm one instruction at a time,
# and the property tests compare every emitted form against it.
using CasADiCodegen.Codegen: OPERATIONS, global_ref

# One Julia function per operation, built from the expressions of the emitter.
const OPERATION_FUNCTIONS = Dict{Symbol,Function}(
    op => Core.eval(@__MODULE__, entry.arity == 1 ?
            :(a -> $(entry.build(global_ref, :a))) :
            :((a, b) -> $(entry.build(global_ref, :a, :b))))
    for (op, entry) in OPERATIONS)

function interpret!(res, alg, arg)
    w = Vector{promote_type(Float64, map(eltype, arg)...)}(undef, alg.nwork)
    for ins in alg.instructions
        # Loop invariant: `w` holds the value of every slot written so far
        # (the `Algorithm` invariant guarantees that no slot is read before that).
        op = ins.op
        if op === :OP_INPUT
            w[ins.out] = arg[ins.a][ins.b]
        elseif op === :OP_OUTPUT
            res[ins.out][ins.b] = w[ins.a]
        elseif op === :OP_CONST
            w[ins.out] = ins.constant
        else
            f = OPERATION_FUNCTIONS[op]
            w[ins.out] = OPERATIONS[op].arity == 1 ? f(w[ins.a]) : f(w[ins.a], w[ins.b])
        end
    end
    res
end
