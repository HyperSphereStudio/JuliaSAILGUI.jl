using Pkg

macro install(x)
    try
        @eval(using $x)
    catch 
        Pkg.add(string($x))
        @eval(using $x)
    end
end

@install(PackageCompiler)

println("Pulling from git...")
Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]
make_sys_image = parse(Bool, ARGS[3])

if make_sys_image
   println("Warming environment...") 
   modules = eval(
        quote 
            using JuliaSAILGUI 
            
            println("Initializing Create Image!")
            JuliaSAILGUI.run_test() 

            return [ccall(:jl_module_usings, Any, (Any,), @__MODULE__)..., @__MODULE__]
        end) 
   invalid_modules = [Base, Main, Core]  
   println("Compiling Image...")   
   create_sysimage(map(nameof, filter(m -> !(m in invalid_modules), modules)); sysimage_path=dllname)
end 
    
println("Created file \"gui.bat\"")
open("gui.bat", "w") do f
    write(f, "julia --sysimage $dllname $scriptname")
end