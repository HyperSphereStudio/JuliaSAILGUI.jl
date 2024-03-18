module JuliaSAILGUI
	using Reexport
	@reexport using GLMakie, Observables, LibSerialPort, HTTP, FileIO, GeometryBasics
	using GLMakie, Observables, LibSerialPort, FileIO, PrecompileTools, DataFrames

    include("MouseTrapExt/MousetrapExt.jl")
    include("MicroControllerPort.jl")
    include("Math.jl")

	using Mousetrap
	
	Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)

    function __init__()
        init_ports()
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