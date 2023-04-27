module JuliaSAILGUI
    using Gtk, CairoMakie, Observables, CSV, Dates, DataFrames, LibSerialPort

    export gui_main, makie_draw, gtk_fixed_move, gtk_to_string

    include("MicroControllerPort.jl")

    CairoMakie.activate!()

    function makie_draw(canvas, fig)
        @guarded draw(canvas) do _
           scene = fig.scene
           resize!(scene, Gtk.width(canvas), Gtk.height(canvas))
           config = CairoMakie.ScreenConfig(1.0, 1.0, :good, true, true)
           screen = CairoMakie.Screen(scene, config, Gtk.cairo_surface(canvas))
           CairoMakie.cairo_draw(screen, scene)
        end
        show(canvas)
    end
    
    gtk_fixed_move(fixed, widget, x, y) = ccall((:gtk_fixed_move, Gtk.libgtk), Nothing, (Ptr{GObject}, Ptr{GObject}, Cint, Cint), fixed, widget, x, y)
    
    gtk_to_string(s) = s == C_NULL ? "" : Gtk.bytestring(s)

    function run_test()
        @eval(@__MODULE__, quote 
            fig = Figure()
            ax = Axis(fig[1, 1])
            d = DataFrame(test=[1, 2, 3], test2=[1, 2, 3])
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
    end
end