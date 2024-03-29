using Mousetrap
using MacroTools

export @SetMousetrapProperties, g_timeout_add, g_idle_add, display_error

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

const JuliaReferences = Tuple{Function, Function}[]

julia_create_ref(f, on_error_function) = (push!(JuliaReferences, (f, on_error_function)); length(JuliaReferences))
const julia_src_function = @cfunction(
    function src_function(x)
        try
            return Cint(JuliaReferences[x][1]())
        catch e
            try
                JuliaReferences[x][2](e)
            catch e2
                display_error(e2)
            end
            return Cint(false)
        end
    end, Cint, (Cint, ))
const julia_destroy_create_ref_c = @cfunction(
    function julia_destroy_ref(x)
        deleteat!(JuliaReferences, x)
        return nothing
    end, Cvoid, (Cint, ))

display_error(e) = showerror(stdout, e, catch_backtrace())    
function g_timeout_add(f::Function, interval::Integer; on_error_function::Function = display_error)
    ccall((:g_timeout_add_full, libglib), Cint, (Cint, UInt32, Ptr{Cvoid}, Cint, Ptr{Cvoid}), Int32(0), UInt32(interval), julia_src_function, julia_create_ref(f, on_error_function), julia_destroy_create_ref_c)
end
function g_idle_add(f::Function; on_error_function::Function = display_error)
    ccall((:g_idle_add_full, libglib), Cint, (Cint, Ptr{Cvoid}, Cint, Ptr{Cvoid}), Int32(0), julia_src_function, julia_create_ref(f, on_error_function), julia_destroy_create_ref_c)
end