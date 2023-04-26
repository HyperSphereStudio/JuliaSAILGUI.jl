using Pkg, PackageCompiler

Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]
make_sys_image = parse(Bool, ARGS[3])

if make_sys_image
   eval(quote using JuliaSAILGUI end)
   create_sysimage(nothing; sysimage_path=dllname)
end 
    
open("gui.bat", "w") do f
    write(f, "julia --sysimage $dllname $scriptname")
end