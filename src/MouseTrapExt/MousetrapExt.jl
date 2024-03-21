using Mousetrap
using MacroTools

export @SetMousetrapProperties, g_timeout_add, g_idle_add 

include("Observables.jl")
include("theme_hypersphere.jl")

macro SetMousetrapProperties(x, args...)
    block = Expr(:block)

    for arg in args
        @capture(arg, name_ = val_) || error("Expr doesnt Match Pattern!")
        push!(block.args, :($(Symbol("set_$(name)!"))($x, $val)))
    end

    return block
end

function Base.empty!(ax::Axis3)
    while !isempty(ax.scene.plots)
        delete!(ax.scene, ax.scene.plots[end])
    end
end

using Glib_jll

const JuliaReferences = Any[]

julia_create_ref(x) = (push!(JuliaReferences, x); length(JuliaReferences))
const julia_src_function = @cfunction((x) -> Cint(JuliaReferences[x]()), Cint, (Cint, ))
const julia_destroy_create_ref_c = @cfunction(
    function julia_destroy_ref(x)
        deleteat!(JuliaReferences, x)
        return nothing
    end, Cvoid, (Cint, ))

function g_timeout_add(f, interval::Integer)
    ccall((:g_timeout_add_full, libglib), Cint, (Cint, UInt32, Ptr{Cvoid}, Cint, Ptr{Cvoid}), Int32(0), UInt32(interval), julia_src_function, julia_create_ref(f), julia_destroy_create_ref_c)
end
function g_idle_add(f)
    ccall((:g_idle_add_full, libglib), Cint, (Cint, Ptr{Cvoid}, Cint, Ptr{Cvoid}), Int32(0), julia_src_function, julia_create_ref(f), julia_destroy_create_ref_c)
end