# The changes to the front end, made when its generated module `casadi` is included:
# the numbers in a Dict of options keep their type (see options.jl), and `jacobian`
# of a graph with an integrator of CasADi with an event function gives the Jacobian of
# forward directions, because CasADi 3.8.1 gives such an integrator the sparsity
# pattern of the model without events (see `Codegen.event_jacobian`).

# The code generation, which holds the methods that the changed `jacobian` calls. The
# module is defined after the front end, so the call finds it when it runs.
const CODEGEN = GlobalRef(@__MODULE__, :Codegen)

"""
    event_definitions!(ex, count::Ref{Int}) -> ex

Rewrite the methods `jacobian(ex::MX, arg::MX...)` and `jacobian(self::Function)` in `ex`,
so that they first call `Codegen.event_jacobian` and `Codegen.check_jacobian`; `count` is
increased by the number of rewritten methods.
"""
function event_definitions!(ex, count::Ref{Int})
    ex isa Expr || return ex
    if Meta.isexpr(ex, (:(=), :function)) && (signature = call_signature(ex.args[1])) !== nothing
        signature.args[1] === :jacobian || return ex
        arguments = signature.args[2:end]
        if length(arguments) >= 2 && arguments[1] == :(ex::MX) && arguments[2] == :(arg::MX)
            ex.args[2] = Expr(:block, :((J = $(Expr(:., CODEGEN, QuoteNode(:event_jacobian)))(ex, arg)) === nothing || return J), ex.args[2])
            count[] += 1
        elseif arguments == [:(self::Function)]
            ex.args[2] = Expr(:block, :($(Expr(:., CODEGEN, QuoteNode(:check_jacobian)))(self)), ex.args[2])
            count[] += 1
        end
        return ex
    end
    foreach(a -> event_definitions!(a, count), ex.args)
    ex
end

"""
    typed_front_end(ex)

The expression `ex` of the convenience layer of the front end, with the include of
the generated module `casadi` given `typed_module` as its `mapexpr`.
"""
function typed_front_end(ex)
    Meta.isexpr(ex, :call) && ex.args[1] === :include && length(ex.args) == 2 || return ex
    Expr(:call, :include, typed_module, ex.args[2])
end

function typed_module(ex)
    Meta.isexpr(ex, :module) || return ex
    count = Ref(0)
    typed_definitions!(ex, count)
    count[] > 100 || throw(AssertionError("only $(count[]) functions of the front end take options; the front end has changed"))
    jacobians = Ref(0)
    event_definitions!(ex, jacobians)
    jacobians[] == 3 || throw(AssertionError("$(jacobians[]) methods of jacobian of the front end were found, not 3; the front end has changed"))
    ex
end
