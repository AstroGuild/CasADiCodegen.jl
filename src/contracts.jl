# Executable contracts. `@assert` can be compiled out, so these always run.

"""
    @requires cond msg

Check a precondition: throw `ArgumentError(msg)` when `cond` is false.
"""
macro requires(cond, msg)
    :($(esc(cond)) || throw(ArgumentError($(esc(msg)))))
end

"""
    @ensures cond msg

Check a postcondition or an invariant: throw `AssertionError(msg)` when `cond`
is false.
"""
macro ensures(cond, msg)
    :($(esc(cond)) || throw(AssertionError($(esc(msg)))))
end
