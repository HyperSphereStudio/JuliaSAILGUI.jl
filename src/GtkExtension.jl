export gtk_fixed_move, gtk_to_string, makewidgetwithtitle, buttonwithimage

Observables.on(@nospecialize(cb::Function), b::GtkButton) = signal_connect(cb, b, "clicked")
Observables.on(@nospecialize(cb::Function), b::GtkComboBoxText) = signal_connect(cb, b, "changed")
Observables.on(@nospecialize(cb::Function), b::GtkAdjustment) = signal_connect(cb, b, "value-changed")

Base.getindex(g::GtkAdjustment) = Gtk4.value(g)
Base.getindex(g::GtkComboBoxText) = gtk_to_string(Gtk4.active_text(g))
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
gtk_to_string(s) = s == C_NULL ? "" : Gtk4.bytestring(s)