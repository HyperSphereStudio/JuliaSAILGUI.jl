export gtk_fixed_move, makewidgetwithtitle, buttonwithimage, makewidgetswithtitle, signal_block

export GtkJuliaStore, GtkJuliaColumnViewColumn

using Gtk4: GObject, G_, GLib, GLib.GListStore, libgio, libgtk4

on_update_signal_name(::GtkButton) = "clicked"
on_update_signal_name(::GtkComboBoxText) = "changed"
on_update_signal_name(::GtkAdjustment) = "value-changed"
on_update_signal_name(::GtkEntry) = "activate"

Observables.on(@nospecialize(cb::Function), w::GObject) = signal_connect(cb, w, on_update_signal_name(w))
Observables.connect!(w::GtkWidget, o::AbstractObservable) = on(v -> w[] = v, o)

Base.getindex(g::GtkEntry, ::Type{String}) = g.text
Base.getindex(g::GtkLabel, ::Type{String}) = g.label
Base.getindex(g::Union{GtkEntry, GtkLabel}, t::Type = String) = parse(g[String], t)
Base.setindex!(g::GtkLabel, v) = g.label = string(v)
Base.setindex!(g::GtkEntry, v) = g.text = string(v)

Base.getindex(g::GtkComboBoxText, ::Type{String} = String) = Gtk4.active_text(g)
Base.getindex(g::GtkComboBoxText, ::Type{Integer}) = g.active
Base.setindex!(g::GtkComboBoxText, v::Integer) = g.active = v
Base.setindex!(g::GtkComboBoxText, v::String) = Gtk4.active_text(g, v)

Base.getindex(g::GtkAdjustment, ::Type{T} = Number) where T <: Number = Gtk4.value(g)
Base.setindex!(g::GtkAdjustment, v) = Gtk4.value(g, v)

function Gtk4.set_gtk_property!(o::GObject, name::String, value::AbstractObservable) 
    set_gtk_property!(o, name, value[])
    on(v -> set_gtk_property!(o, name, v), value)
end

function Observables.ObservablePair(w::GObject, o::AbstractObservable{T}) where T
    w[] = o[]
    done = Ref(false)
    on(w) do w
        if !done[]
            done[] = true
            o[] = w[T]
            done[] = false
        end
    end
    on(o) do val
        if !done[]
            done[] = true
            w[] = val
            done[] = false
        end
    end
end

Base.append!(cv::GtkColumnView, cvc::GtkColumnViewColumn) = G_.append_column(cv, cvc)

GtkNoSelection(model) = G_.NoSelection_new(model)

mutable struct GtkJuliaStore
    items::Dict{Ptr{GObject}, Any}
    store::GListStore
    freeNames::Array{Ptr{GObject}}

    GtkJuliaStore() = new(Dict{Ptr{GObject}, Any}(), GLib.GListStore(:GObject), Ptr{GObject}[])
    GtkJuliaStore(items::AbstractArray) = (g = GtkJuliaStore(); append!(g, items); return g)
    GtkJuliaStore(items...) = GtkJuliaStore(collect(items))

    Gtk4.GListModel(g::GtkJuliaStore) = Gtk4.GListModel(g.store)
    Base.getindex(g::GtkJuliaStore, i::Integer) = g.items[unsafegetname(g.store, i)]
    Base.setindex!(g::GtkJuliaStore, v, i::Integer) = g.items[unsafegetname(g.store, i)] = v
    Base.keys(lm::GtkJuliaStore) = keys(g.store)
    Base.eltype(::Type{GtkJuliaStore}) = Any
    Base.iterate(g::GtkJuliaStore, i=0) = (i == length(g) ? nothing : (getindex(g, i + 1), i + 1))
    Base.length(g::GtkJuliaStore) = length(g.store)
    Base.empty!(g::GtkJuliaStore) = (empty!(g.items); empty!(g.store); empty!(freeNames))
    Base.pushfirst!(g::GtkJuliaStore, item) = insert!(g, 1, item)
    Base.append!(g::GtkJuliaStore, items) = foreach(x -> push!(g, x), items)
    Base.getindex(g::GtkJuliaStore, i::GtkListItem) = g.items[ccall(("gtk_list_item_get_item", libgtk4), Ptr{GObject}, (Ptr{GObject},), i)]
    Base.setindex!(g::GtkJuliaStore, v, i::GtkListItem) = g.items[ccall(("gtk_list_item_get_item", libgtk4), Ptr{GObject}, (Ptr{GObject},), i)] = v
    unsafegetname(ls::GListStore, i) = ccall(("g_list_model_get_object", libgio), Ptr{GObject}, (Ptr{GObject}, UInt32), ls, i-1)

    function nextname(g::GtkJuliaStore)
        name = length(g.freeNames) == 0 ? Symbol("$(length(g))") : pop!(g.freeNames)
        return ccall(("gtk_string_object_new", libgtk4), Ptr{GObject}, (Cstring,), name)
    end

    function Base.push!(g::GtkJuliaStore, item)
        name = nextname(g)
        ccall(("g_list_store_append", libgio), Nothing, (Ptr{GObject}, Ptr{GObject}), g.store, name)
        g.items[name] = item
        return nothing
    end

    function Base.insert!(g::GtkJuliaStore, i::Integer, item)
        name = nextname(g)
        ccall(("g_list_store_insert", libgio), Nothing, (Ptr{GObject}, UInt32, Ptr{GObject}), g.store, i-1, name)
        g.items[name] = item
        return nothing
    end

    function Base.deleteat!(g::GtkJuliaStore, i::Integer)
        name = unsafegetname(g.store, i)
        push!(freeNames, name)
        delete!(g.items, name)
        ccall(("g_list_store_remove", libgio), Nothing, (Ptr{GObject}, UInt32), g.store, i-1)
        return nothing
    end   
end

function GtkJuliaColumnViewColumn(store::GtkJuliaStore, name::String, @nospecialize(init_child::Function), @nospecialize(update_child::Function))
    factory = GtkSignalListItemFactory()
    signal_connect((f, li) -> set_child(li, init_child()), factory, "setup")
    signal_connect((f, li) -> update_child(get_child(li), store[li]), factory, "bind")
    return GtkColumnViewColumn(name, factory)
end






function makewidgetwithtitle(widget, label)
    grid = GtkGrid()
    lbl = GtkLabel(label; hexpand=true)
    Gtk4.markup(lbl, "<b>$label</b>")
    grid[1, 1] = lbl
    grid[1, 2] = widget
    return grid
end

makewidgetswithtitle(widgets, labels) = [makewidgetwithtitle(widgets[i], labels[i]) for i in eachindex(widgets)]

function buttonwithimage(label, img)
    box = GtkBox(:h; hexpand=true)
    append!(box, GtkLabel(label; hexpand=true), img)
    return GtkButton(box)
end

Base.append!(b::GtkWidget, items::AbstractArray) = foreach(x->push!(b, x), items)
Base.append!(b::GtkWidget, items...) = foreach(x->push!(b, x), items)

gtk_fixed_move(fixed, widget, x, y) = ccall((:gtk_fixed_move, Gtk4.libgtk4), Nothing, (Ptr{GObject}, Ptr{GObject}, Cint, Cint), fixed, widget, x, y)

signal_block(f, g, handler_id) = (signal_handler_block(g, handler_id); f(g); signal_handler_unblock(g, handler_id))