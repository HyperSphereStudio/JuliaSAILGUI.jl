export gtk_fixed_move, gtk_to_string, makewidgetwithtitle, buttonwithimage

Observables.on(@nospecialize(cb::Function), b::GtkButton) = signal_connect(cb, b, "clicked")
Observables.on(@nospecialize(cb::Function), b::Union{GtkComboBoxText, GtkEntry}) = signal_connect(cb, b, "changed")
Observables.on(@nospecialize(cb::Function), b::GtkAdjustment) = signal_connect(cb, b, "value-changed")

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

function buttonwithimage(label, img)
    box = GtkBox(:h; hexpand=true)
    append!(box, GtkLabel(label; hexpand=true), img)
    return GtkButton(box)
end

Base.append!(b::GtkBox, items...) = foreach(x->push!(b, x), items)

gtk_fixed_move(fixed, widget, x, y) = ccall((:gtk_fixed_move, Gtk4.libgtk4), Nothing, (Ptr{GObject}, Ptr{GObject}, Cint, Cint), fixed, widget, x, y)