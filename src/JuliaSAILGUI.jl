module JuliaSAILGUI
	using Reexport
	@reexport using GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools, Optim, ForwardDiff, GeometryBasics
	using GLMakie, Observables, LibSerialPort, FileIO, PrecompileTools, DataFrames

    include("MouseTrapExt/MousetrapExt.jl")
    include("MicroControllerPort.jl")
	include("SimplePlot.jl")
    include("Math.jl")

	using Mousetrap
	
	Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)

    function __init__()
        init_ports()
		GLMakie.activate!()
    end

	function test_makie()
		d = DataFrame(test=[1, 2, 3], test2=[1, 2, 3])

        set_theme!(theme_hypersphere())
        fig = Figure()
		
        ax = Axis(fig[1, 1])
        ax3 = Axis3(fig[1, 2], xlabel="", ylabel="", zlabel="")
        lines!(ax, Observable(d.test), Observable(d.test2))
        scatter!(ax, [2, 3, 4], [3, 4, 5])
        scatter!(ax3, [Point3f(5, 3, 5)])
	end
	
	function test_port()
		p = MicroControllerPort(:Random, 9600, DelimitedReader("\r\n"))
		isopen(p) && readport(p) do str end
	end

    @setup_workload begin
        @compile_workload begin
            using GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools

			GLMakie.activate!()
			test_port()
			test_makie()
        end
    end
end