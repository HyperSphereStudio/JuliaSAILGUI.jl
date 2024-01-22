using Pkg

macro install(x)
    try
        @eval(using $x)
    catch 
        Pkg.add(string(x))
        @eval(using $x)
    end
end

@install(PackageCompiler)
@install(Reexport)

println("Pulling from git...")
Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]

println("Compile System Image [true/false]?")
if parse(Bool, readline())
   println("Compiling Image to $dllname")   
   ENV["SYS_COMPILING"] = true
   create_sysimage(["JuliaSAILGUI"]; sysimage_path=dllname)
end 
    
println("Creating System Image Executable File \"gui.bat\"")
open("gui.bat", "w") do f
	try run(`juliaup remove juliasailgui`) catch _ end
	
	#Disable Pkg Images to help with firewall
	success(Cmd(`juliaup link juliasailgui julia -- --pkgimages=no --sysimage $dllname`, dir=Sys.BINDIR))
	
    write(f, "julia +juliasailgui $scriptname")
end