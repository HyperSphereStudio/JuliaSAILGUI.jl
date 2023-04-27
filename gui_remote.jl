using Pkg, PackageCompiler

Pkg.add(url="https://github.com/HyperSphereStudio/JuliaSAILGUI.jl")

dllname = joinpath(Sys.BINDIR, ARGS[1])
scriptname = ARGS[2]
make_sys_image = parse(Bool, ARGS[3])

if make_sys_image
   eval(quote 
        using JuliaSAILGUI, Dates, DataFrames, Gtk, CairoMakie, Makie, Observables, CSV 

        fig = Figure()
        ax = Axis(fig[1, 1])
        d = DataFrame(test=>[1, 2, 3], test2=>[1, 2, 3])
        lines!(ax, Observable(d.test), Observable(d.test2))

        win = GtkWindow()
        box = GtkBox(:v)
        push!(win, box)
        can = GtkCanvas(200, 200)
        push!(box, can)
        makie_draw(can, fig)

        @async showall(win)
        @async Gtk.gtk_main()

        makie_draw(can, fig)
    end)
   create_sysimage(nothing; sysimage_path=dllname)
end 
    
open("gui.bat", "w") do f
    write(f, "julia --sysimage $dllname $scriptname")
end