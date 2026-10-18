module CasADiCodegenDifferentiationInterfaceExt

import ADTypes
import CasADiCodegen
import DifferentiationInterface

"Split the vector `z` into arrays of the given shapes."
function pieces(z, shapes)
    offset = 0
    map(shapes) do dims
        part = z[offset+1:offset+prod(dims)]
        offset += prod(dims)
        length(dims) == 1 ? part : reshape(part, dims)
    end
end

function CasADiCodegen.Codegen.backend_jacobian(f, backend::ADTypes.AbstractADType, shapes_in, sizes_out)
    sizes_in = map(prod, shapes_in)
    stacked(z) = reduce(vcat, map(vec, CasADiCodegen.Codegen.results(f(pieces(z, shapes_in)...))))
    rows = pieces(1:sum(sizes_out), [(n,) for n in sizes_out])
    columns = pieces(1:sum(sizes_in), [(n,) for n in sizes_in])
    function (arguments...)
        J = DifferentiationInterface.jacobian(stacked, backend, reduce(vcat, map(vec, arguments)))
        Tuple(J[r, c] for r in rows for c in columns)
    end
end

end # module
