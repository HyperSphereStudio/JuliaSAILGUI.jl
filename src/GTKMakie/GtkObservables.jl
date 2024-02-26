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

Observables.on(@nospecialize(cb::Function), w::GObject; settings...) = signal_connect(cb, w, on_update_signal_name(w); settings...)
Observables.connect!(w::GtkWidget, o::AbstractObservable{T}) where T = on(v -> w[T] = v, o)

function Gtk4.set_gtk_property!(o::GObject, name::String, value::AbstractObservable) 
    set_gtk_property!(o, name, value[])
    on(v -> set_gtk_property!(o, name, v), value)
end