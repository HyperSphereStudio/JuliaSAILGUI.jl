module JuliaSAILGUI
    using GLMakie, Observables, CSV, Dates, DataFrames, LibSerialPort
    using Gtk4.GLib: GObject, signal_handler_is_connected, signal_handler_disconnect
    using GLMakie.GLAbstraction
    using GLMakie.Makie
    using GLMakie: empty_postprocessor, fxaa_postprocessor, OIT_postprocessor, to_screen_postprocessor
    using GLMakie.Makie: MouseButtonEvent, KeyEvent
    export gtk_fixed_move, gtk_to_string

    include("MicroControllerPort.jl")
    
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

            display(fig)
            @async showall(win)
            @async Gtk.gtk_main()
        end)
    end
end