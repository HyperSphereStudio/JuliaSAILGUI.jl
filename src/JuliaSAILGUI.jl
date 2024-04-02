module JuliaSAILGUI
	using Reexport
	@reexport using GLMakie, Observables, LibSerialPort, HTTP, FileIO, GeometryBasics
	using GLMakie, Observables, LibSerialPort, FileIO, PrecompileTools, DataFrames
	
	export dict, Expando

    include("MouseTrapExt/MousetrapExt.jl")
    include("MicroControllerPort.jl")
    include("Math.jl")

	using Mousetrap
	
	Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)
	dict(; values...) = Dict(values...)

	struct Expando{T}
		dict::Dict{Symbol, T}

		Expando{T}(; args...) where T = new{T}(Dict{Symbol, T}(collect(args)))
		Expando() = Expando{Any}()

		Base.getproperty(x::Expando, s::Symbol) = getfield(x, :dict)[s]
		Base.setproperty!(x::Expando, s::Symbol, v) = getfield(x, :dict)[s] = v
		Base.delete!(x::Expando, s) = delete!(Dict(x), s)
		Base.keys(x::Expando) = keys(Dict(x))
		Base.values(x::Expando) = values(Dict(x))
		Base.Dict(x::Expando) = x.dict
	end 

    function __init__()
        init_ports()
		init_mousetrap()
    end
	
	function test_port()
		p = MicroControllerPort(:Random, 9600, DelimitedReader("\r\n"))
		isopen(p) && readport(p) do str end
	end

    @setup_workload begin
        @compile_workload begin
            using GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools
	    test_port()
        end
    end
end