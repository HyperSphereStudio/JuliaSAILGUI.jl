module JuliaSAILGUI
    using Reexport

    @reexport using Gtk4, GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools

    export HTimer

    Base.isopen(::Nothing) = false
    Base.append!(d::Dict, items::Pair...) = foreach(p -> d[p[1]] = p[2], items)

    include("MakieExtension.jl")
    include("GtkExtension.jl")
    include("MicroControllerPort.jl")
    include("theme_hypersphere.jl")
    include("Math.jl")

    mutable struct HTimer
        t::Union{Nothing, Timer}
        cb::Function
        delay::Real
        interval::Real
    
        HTimer(cb::Function, delay, interval = 0; start=true) = (t = new(nothing, cb, delay, interval); start && resume(t); return t)
        Base.close(h::HTimer) = h.t !== nothing && (close(h.t); h.t = nothing)
    end
    resume(h::HTimer) = h.t === nothing && (h.t = Timer(h.cb, h.delay; interval=h.interval))
    pause(h::HTimer) = close(h)

    function __init__()
        init_ports()
        gtk_init()
    end

    @setup_workload begin
        @compile_workload begin
            using Gtk4, GLMakie, Observables, CSV, DataFrames, LibSerialPort, HTTP, FileIO, PrecompileTools

            d = DataFrame(test=[1, 2, 3], test2=[1, 2, 3])
            CSV.write("test.csv", d)

            set_theme!(theme_hypersphere())
            fig = Figure()

            ax = Axis(fig[1, 1])
            ax3 = Axis3(fig[1, 2], xlabel="", ylabel="", zlabel="")
            lines!(ax, Observable(d.test), Observable(d.test2))
            scatter!(ax, [2, 3, 4], [3, 4, 5])
            scatter!(ax3, [Point3f(5, 3, 5)])
            window, screen = GtkGLWindow(fig)
            display_gui(window; blocking=false)

            p = MicroControllerPort(:Random, 9600, DelimitedReader("\r\n"))

            isopen(p) && readport(p) do str end
        end
        rm("test.csv"; force=false)
    end

end