export gtk_fixed_move, gtk_to_string, makewidgetwithtitle, buttonwithimage, makewidgetswithtitle, signal_block 


mutable struct GtkValueEntry{T} <: GtkWidget
    handle::Ptr{Gtk4.GLib.GObject}
    value::T
    callback::Function
    handler::Culong

    function GtkValueEntry{T}(init_value, args...; kargs...) where T
        entry = GtkEntry(args...; kargs...)
        ventry = Gtk4.GLib.gobject_move_ref(new(entry.handle, T(init_value), x->(), 0), entry)
        ventry.text = string(ventry.value)
        ventry.handler = signal_connect(ventry, "activate") do x
            v = tryparse(T, x.text)
            if v !== nothing
                x.value = v
                x.callback(x)
            end
        end
        ventry
    end

    Base.getindex(g::GtkValueEntry{T}) where T = g.value
    Base.getindex(g::GtkValueEntry) = g.value
    Base.setindex!(g::GtkValueEntry{T}, v) where T = (g.value = T(v); signal_block(g -> g.text = string(g.value), g, g.handler))
    Observables.on(@nospecialize(cb::Function), b::GtkValueEntry) = b.callback = cb
end

Observables.on(@nospecialize(cb::Function), b::GtkButton) = signal_connect(cb, b, "clicked")
Observables.on(@nospecialize(cb::Function), b::GtkComboBoxText) = signal_connect(cb, b, "changed")
Observables.on(@nospecialize(cb::Function), b::GtkAdjustment) = signal_connect(cb, b, "value-changed")
Observables.on(@nospecialize(cb::Function), b::GtkEntry) = signal_connect(cb, b, "activate")

Base.getindex(g::GtkEntry, t::Type = String) = parse(t, g.text)
Base.getindex(g::GtkEntry, ::Type{String}) = g.text
Base.getindex(g::GtkAdjustment) = Gtk4.value(g)
Base.getindex(g::GtkComboBoxText) = Gtk4.active_text(g)

Base.setindex!(g::GtkEntry, v) = g.text = string(v)
Base.setindex!(g::GtkAdjustment, v) = Gtk4.value(g, v)

function makewidgetwithtitle(widget, label)
    grid = GtkGrid()
    lbl = GtkLabel(label; hexpand=true)
    Gtk4.markup(lbl, "<b>$label</b>")
    grid[1, 1] = lbl
    grid[1, 2] = widget
    return grid
end

makewidgetswithtitle(widgets, labels) = [makewidgetwithtitle(widgets[i], labels[i]) for i in 1:length(widgets)]

function buttonwithimage(label, img)
    box = GtkBox(:h; hexpand=true)
    append!(box, GtkLabel(label; hexpand=true), img)
    return GtkButton(box)
end

Base.append!(b::GtkWidget, items::AbstractArray) = foreach(x->push!(b, x), items)
Base.append!(b::GtkWidget, items...) = foreach(x->push!(b, x), items)

gtk_fixed_move(fixed, widget, x, y) = ccall((:gtk_fixed_move, Gtk4.libgtk4), Nothing, (Ptr{GObject}, Ptr{GObject}, Cint, Cint), fixed, widget, x, y)

signal_block(f, g, handler_id) = (signal_handler_block(g, handler_id); f(g); signal_handler_unblock(g, handler_id))