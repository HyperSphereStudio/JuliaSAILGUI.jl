using Pkg

macro install(x)
    try
        @eval(using $x)
    catch 
        Pkg.add(string(x))
        @eval(using $x)
    end
end

println("New System Environment [true/false]?")
if parse(Bool, readline())
	Pkg.activate("--temp")
end

println("Pulling from git...")
Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]

println("Compile System Image [true/false]?")
if parse(Bool, readline())
   @install(PackageCompiler)
   
   println("Compiling Image to $dllname")   
   ENV["SYS_COMPILING"] = true
   create_sysimage(["JuliaSAILGUI"]; sysimage_path=dllname)
end 
    
println("Creating System Image Executable File \"gui.bat\"")
open("gui.bat", "w") do f
	try run(`juliaup remove juliasailgui`) catch _ end
	success(Cmd(`juliaup link juliasailgui julia -- --sysimage $dllname`, dir=Sys.BINDIR))
    write(f, "julia +juliasailgui $scriptname")
end