module CasADiCodegenSparseArraysExt

import CasADiCodegen
import CasADiNative
import SparseArrays
import CasADiCodegen.Codegen.Helpers: stored, is_stored

# The methods of `stored` and `is_stored` for a sparse matrix, for generated code.
include_string(@__MODULE__, CasADiCodegen.Codegen.SPARSE_HELPER_SOURCE)

"""
    SparseMatrixCSC(sparsity::CasADiNative.Sparsity) -> SparseMatrixCSC{Float64,Int}

Make a sparse matrix of stored zeros with the sparsity pattern `sparsity`. Use it as an
output or an input of the in-place function of `build_function` or `generate_julia`, which
then reads and writes the stored values only.

# Examples
```julia
using CasADiNative, CasADiCodegen, SparseArrays

x = SX.sym("x", 2)
f = CasADiNative.Function("f", [x], [jacobian([x[1]^2; x[1] * x[2]], x)])
J = SparseMatrixCSC(CasADiNative.sparsity_out(f, 0))      # 2×2 with 3 stored entries
_, g! = build_function(f; expression = Val{false})
g!((J,), ([2.0, 3.0],))                             # J is now [4.0 0.0; 3.0 2.0]
```
"""
function SparseArrays.SparseMatrixCSC(sparsity::CasADiNative.C.Sparsity)
    nrow, ncol, colptr, rowval = CasADiCodegen.Codegen.sparsity_tuple(sparsity)
    SparseArrays.SparseMatrixCSC(nrow, ncol, colptr, rowval, zeros(length(rowval)))
end

end # module CasADiCodegenSparseArraysExt
