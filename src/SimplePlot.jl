export SimplePlot, init, dict

mutable struct SimplePlot{T}
	config; plot
	SimplePlot{T}(; config...) where T = new{T}(Dict{Symbol, Any}(config))
    SimplePlot(; config...) = SimplePlot{Any}(; config...)
    Base.getindex(p::SimplePlot, name) = p.config[name]
    Base.setindex(p::SimplePlot, v, name) = p.config[name] = v
end

dict(; values...) = Dict(values...)
init(p::SimplePlot, fig) = p.plot = Axis(fig[p[:loc]...]; p[:plot_config]...)
init(p::SimplePlot) = ()
Base.reset(p::SimplePlot) = empty!(p.plot)