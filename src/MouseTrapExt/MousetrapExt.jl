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