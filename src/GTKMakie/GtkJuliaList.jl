export GtkJuliaList, GtkJuliaColumnViewColumn

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

Base.append!(cv::GtkColumnView, cvc::GtkColumnViewColumn) = G_.append_column(cv, cvc)

GtkNoSelection(model) = G_.NoSelection_new(model)