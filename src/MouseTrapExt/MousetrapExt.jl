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

Mousetrap.@export_function ColumnView set_show_row_separators! Cvoid Bool b
Mousetrap.@export_function ColumnView set_show_column_separators! Cvoid Bool b