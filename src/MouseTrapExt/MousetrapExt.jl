using Mousetrap
using MacroTools

export @SetMousetrapProperties

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

function Base.setindex!(grid::Grid, child, i, j)
    insert_at!(grid, child, first(i)-1, first(j)-1, length(i), length(j))
end



function init_mousetrap()
	eval(quote
	
	# Quick Patch to prevent crashing
using Mousetrap.detail

function Mousetrap.connect_signal_render!(f, gla::GLArea)
    typed_f = TypedFunction(f, Bool, (GLArea, Ptr{Cvoid}))
    detail.connect_signal_render!(gla._internal, function(x)
        typed_f(gla, x[2])
    end)
end

	end)
end