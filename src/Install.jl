using Pkg

Pkg.activate("JuliaGUIEnv", shared=true)

println("Install Core Libraries [Y/N]?")

if read(stdin, Char) == "Y"
	Pkg.add(PackageSpec(name="GLMakie", version="0.8.11"))
	try Pkg.rm("mousetrap") catch end
	try Pkg.rm("mousetrap_windows_jll") catch end
	try Pkg.rm("mousetrap_linux_jll") catch end
	try Pkg.rm("mousetrap_apple_jll") catch end
	try Pkg.rm("libmousetrap_jll") catch end
	try Pkg.rm("MousetrapMakie") catch end

	Pkg.add(url="https://github.com/clemapfel/mousetrap.jl")
	Pkg.add(url="https://github.com/clemapfel/mousetrap_jll")
	Pkg.add(url="https://github.com/clemapfel/MousetrapMakie.jl")

	Pkg.add("Glib_jll")
	Pkg.add("Observables")
	Pkg.add("DataFrames")
	Pkg.add("LibSerialPort")
	Pkg.add("ForwardDiff")
	Pkg.add("FileIO")
	Pkg.add("HTTP")
	Pkg.add("DataFrames")
	Pkg.add("CSV")
	Pkg.add("Optim")
	Pkg.add("GeometryBasics")
	Pkg.add("DifferentialEquations")
	Pkg.add("Unitful")
end

Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")