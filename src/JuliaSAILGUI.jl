module JuliaSAILGUI
    using Reexport

    export GtkGLScreen, GtkGLWindow, display_gui

    @reexport using Gtk4, GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, OSMMakie, LightOSM

    Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)

    include("MakieExtension.jl")
    include("GtkExtension.jl")
    include("MicroControllerPort.jl")
    include("theme_hypersphere.jl")

    function run_test()
        fig = Figure()
        ax = Axis(fig[1, 1])
        d = DataFrame(test=[1, 2, 3], test2=[1, 2, 3])
        lines!(ax, Observable(d.test), Observable(d.test2))
        scatter!(ax, [2, 3, 4], [3, 4, 5])
        CSV.write("test.csv", d)
        println("Creating Window")
        window, screen = GtkGLWindow(fig)
        display_gui(window; blocking=false)
    end
end