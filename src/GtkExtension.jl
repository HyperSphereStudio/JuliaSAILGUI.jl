export gtk_fixed_move, makewidgetwithtitle, buttonwithimage, makewidgetswithtitle, signal_block, set_gtk_style!

export GtkJuliaList, GtkJuliaColumnViewColumn

using Gtk4: GObject, G_, GLib, GLib.GListStore, libgio, libgtk4

on_update_signal_name(::GtkButton) = "clicked"
on_update_signal_name(::GtkComboBoxText) = "changed"
on_update_signal_name(::Union{GtkScale, GtkAdjustment}) = "value-changed"
on_update_signal_name(::GtkEntry) = "activate"

Observables.on(@nospecialize(cb::Function), w::GObject) = signal_connect(cb, w, on_update_signal_name(w))
Observables.connect!(w::GtkWidget, o::AbstractObservable{T}) where T = on(v -> w[T] = v, o)

Base.getindex(g::GtkEntry, ::Type{String}) = g.text
Base.getindex(g::GtkLabel, ::Type{String}) = g.label
Base.getindex(g::Union{GtkEntry, GtkLabel}, t::Type = String) = parse(t, g[String])
Base.setindex!(g::GtkLabel, v) = g.label = string(v)
Base.setindex!(g::GtkEntry, v) = g.text = string(v)

Base.getindex(g::GtkComboBoxText, ::Type{String} = String) = Gtk4.active_text(g)
Base.getindex(g::GtkComboBoxText, ::Type{T}) where T <: Integer = g.active
Base.setindex!(g::GtkComboBoxText, v::Integer) = g.active = v
Base.setindex!(g::GtkComboBoxText, v::String) = Gtk4.active_text(g, v)

Base.getindex(g::Union{GtkScale, GtkAdjustment}, ::Type{T} = Number) where T <: Number = Gtk4.value(g)
Base.setindex!(g::Union{GtkScale, GtkAdjustment}, v) = Gtk4.value(g, v)

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

mutable struct GtkJuliaList
    data::AbstractArray
    indexMap::Dict{Ptr{GObject}, Int}
    store::GListStore
    freeNames::Array{Ptr{GObject}}

    GtkJuliaList(items::AbstractArray) = (g = new(items, Dict{Ptr{GObject}, Int}(), GLib.GListStore(:GObject), Ptr{GObject}[]); append!(g, items); return g)  
    GtkJuliaList(items...) = GtkJuliaList(collect(items))

    Gtk4.GListModel(g::GtkJuliaList) = Gtk4.GListModel(g.store)
    Base.getindex(g::GtkJuliaList, i::Integer) = g.data[i]
    Base.setindex!(g::GtkJuliaList, v, i::Integer) = g.data[i] = v
    Base.eltype(g::GtkJuliaList) = eltype(g.data)
    Base.iterate(g::GtkJuliaList, i=0) = iterate(g.data)
    Base.length(g::GtkJuliaList) = length(g.data)
    Base.empty!(g::GtkJuliaList) = foreach(empty!, [g.indexMap, g.store, g.freeNames, g.data])
    Base.pushfirst!(g::GtkJuliaList, item) = insert!(g, 1, item)
    Base.append!(g::GtkJuliaList, items) = foreach(x -> push!(g, x), items)
    Base.getindex(g::GtkJuliaList, i::GtkListItem) = g[g.indexMap[ccall(("gtk_list_item_get_item", libgtk4), Ptr{GObject}, (Ptr{GObject},), i)]]
    Base.setindex!(g::GtkJuliaList, v, i::GtkListItem) = g[g.indexMap[ccall(("gtk_list_item_get_item", libgtk4), Ptr{GObject}, (Ptr{GObject},), i)]] = v
    unsafegetname(ls::GListStore, i) = ccall(("g_list_model_get_object", libgio), Ptr{GObject}, (Ptr{GObject}, UInt32), ls, i-1)

    function nextname(g::GtkJuliaList)
        name = length(g.freeNames) == 0 ? Symbol("$(length(g))") : pop!(g.freeNames)
        return ccall(("gtk_string_object_new", libgtk4), Ptr{GObject}, (Cstring,), name)
    end

    function Base.push!(g::GtkJuliaList, item)
        name = nextname(g)
        push!(g.data, item)
        g.indexMap[name] = length(g.data)
        ccall(("g_list_store_append", libgio), Nothing, (Ptr{GObject}, Ptr{GObject}), g.store, name)
        return nothing
    end

    function Base.insert!(g::GtkJuliaList, i::Integer, item)
        name = nextname(g)
        insert!(g.data, i, item)
        g.indexMap[name] = i
        ccall(("g_list_store_insert", libgio), Nothing, (Ptr{GObject}, UInt32, Ptr{GObject}), g.store, i-1, name)
        return nothing
    end

    function Base.deleteat!(g::GtkJuliaList, i::Integer)
        name = unsafegetname(g.store, i)
        push!(freeNames, name)
        delete!(g.indexMap, name)
        deleteat!(g.data, i)
        ccall(("g_list_store_remove", libgio), Nothing, (Ptr{GObject}, UInt32), g.store, i-1)
        return nothing
    end   
end

function GtkJuliaColumnViewColumn(store::GtkJuliaList, name::String, @nospecialize(init_child::Function), @nospecialize(update_child::Function); kargs...)
    factory = GtkSignalListItemFactory()
    signal_connect((f, li) -> set_child(li, init_child()), factory, "setup")
    signal_connect((f, li) -> update_child(get_child(li), store[li]), factory, "bind")
    return GtkColumnViewColumn(name, factory; kargs...)
end


function makewidgetwithtitle(widget, label::AbstractObservable)
    grid = GtkGrid()
    lbl = GtkLabel(""; hexpand=true)
    on(l -> Gtk4.markup(lbl, "<b>$l</b>"), label; update=true)
    grid[1, 1] = lbl
    grid[1, 2] = widget
    return grid
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

Base.append!(b::GtkWidget, items) = foreach(x -> push!(b, x), items)
Base.append!(b::GtkWidget, items...) = foreach(x -> push!(b, x), items)

gtk_fixed_move(fixed, widget, x, y) = ccall((:gtk_fixed_move, Gtk4.libgtk4), Nothing, (Ptr{GObject}, Ptr{GObject}, Cint, Cint), fixed, widget, x, y)

signal_block(f, g, handler_id) = (signal_handler_block(g, handler_id); f(g); signal_handler_unblock(g, handler_id))

function gtk_init()
    ENV["GTK_THEME"] = "Adwaita:dark"
end

function set_gtk_style!(widget::GtkWidget, str::String)
    sc = Gtk4.style_context(widget)
    pr = Gtk4.GtkCssProvider(data = str)
    push!(sc, Gtk4.GtkStyleProvider(pr))
end