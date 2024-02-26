using ShaderAbstractions, ModernGL
using Gtk4.GLib: GObject, signal_handler_is_connected, signal_handler_disconnect
using GLMakie.GLAbstraction
using GLMakie.Makie
using GLMakie.Makie: MouseButtonEvent, KeyEvent

export shouldblock, GtkGLScreen, GtkGLWindow, display_gui

include("GLScreen.jl")
include("Events.jl")
include("GtkGLArea.jl")
include("theme_hypersphere.jl")

function Base.empty!(ax::Axis3)
    while !isempty(ax.scene.plots)
        delete!(ax.scene, ax.scene.plots[end])
    end
end