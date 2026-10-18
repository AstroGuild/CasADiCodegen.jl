# CasADi operation code => operation name, read once from the loaded library.
const OP_NAMES = Dict{Int,Symbol}()

function op_names()
    if isempty(OP_NAMES)
        for n in names(C; all = true)
            startswith(string(n), "OP_") && (OP_NAMES[getfield(C, n)::Int] = n)
        end
    end
    OP_NAMES
end

"""
    Algorithm(f::CasADiCodegen.Function)

Copy the instruction list of the scalar (SX) function `f`, one instruction per
CasADi instruction. `f` must be an SX function with no free symbols.
"""
function Algorithm(f::C.Function)
    @requires C.is_a(f, "SXFunction") "function \"$(C.name(f))\" is not a scalar (SX) function"
    @requires !C.has_free(f) "function \"$(C.name(f))\" has free symbols: $(C.get_free(f))"
    names = op_names()
    n = C.n_instructions(f)
    instructions = Vector{Instruction}(undef, n)
    for k in 1:n
        op = names[C.instruction_id(f, k - 1)]
        i = C.instruction_input(f, k - 1)
        o = C.instruction_output(f, k - 1)
        instructions[k] = if op === :OP_INPUT
            Instruction(op, o[1] + 1, i[1] + 1, i[2] + 1)
        elseif op === :OP_OUTPUT
            Instruction(op, o[1] + 1, i[1] + 1, o[2] + 1)
        elseif op === :OP_CONST
            Instruction(op, o[1] + 1, 0, 0, C.instruction_constant(f, k - 1))
        else
            @requires haskey(OPERATIONS, op) "function \"$(C.name(f))\": unsupported operation $op at instruction $k"
            arity = OPERATIONS[op].arity
            Instruction(op, o[1] + 1, i[1] + 1, arity == 2 ? i[2] + 1 : 0)
        end
    end
    Algorithm(C.name(f), instructions, C.sz_w(f),
              [C.sparsity_in(f, j) for j in 0:C.n_in(f)-1],
              [C.sparsity_out(f, j) for j in 0:C.n_out(f)-1],
              [C.name_in(f, j) for j in 0:C.n_in(f)-1],
              [C.name_out(f, j) for j in 0:C.n_out(f)-1])
end
