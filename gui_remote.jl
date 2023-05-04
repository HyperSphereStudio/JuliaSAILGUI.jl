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
@install(PrecompileTools)

Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]
make_sys_image = parse(Bool, ARGS[3])

if make_sys_image
   modules = eval(
        quote 
            using JuliaSAILGUI 
            
            println("Initializing Create Image!")

            PrecompileTools.@setup_workload begin
                data = rand(5)
                println("Starting Image Creation Workflow!")
                PrecompileTools.@compile_workload JuliaSAILGUI.run_test() 
                println("Precompiling Type Information...")
            end

            return [ccall(:jl_module_usings, Any, (Any,), @__MODULE__)..., @__MODULE__]
        end) 
   invalid_modules = [Base, Main, Core]  
   println("Compiling Image...")   
   create_sysimage(map(nameof, filter(m -> !(m in invalid_modules), modules)); sysimage_path=dllname)
end 
    
open("gui.bat", "w") do f
    write(f, "julia --sysimage $dllname $scriptname")
end