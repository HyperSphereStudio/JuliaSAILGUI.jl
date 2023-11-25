using ShaderAbstractions, GeometryBasics, ModernGL
using Gtk4.GLib: GObject, signal_handler_is_connected, signal_handler_disconnect
using GLMakie.GLAbstraction
using GLMakie.Makie
using GLMakie: empty_postprocessor, fxaa_postprocessor, OIT_postprocessor, to_screen_postprocessor
using GLMakie.Makie: MouseButtonEvent, KeyEvent
using Optim, ForwardDiff    

export shouldblock, GtkGLScreen, GtkGLWindow, display_gui

Base.isopen(::GtkGLArea) = true
ShaderAbstractions.native_context_alive(a::GtkGLArea) = isopen(a)
ShaderAbstractions.native_switch_context!(a::GtkGLArea) = Gtk4.make_current(a)
GLMakie.framebuffer_size(gla::GtkGLArea) = size(gla) .* GLMakie.retina_scaling_factor(gla)
GLMakie.resize_native!(gla::GtkGLArea, w, h) = gla
Makie.to_native(gla::GtkGLArea) = gla
Makie.window_open(scene::Scene, ::GtkGLArea) = scene.events.window_open[] = true
Makie.hasfocus(scene::Scene, ::GtkGLArea) = scene.events.hasfocus[] = true
Makie.unicode_input(::Scene, ::GtkGLArea) = ()
Makie.dropped_files(::Scene, ::GtkGLArea) = ()
Makie.entered_window(::Scene, ::GtkGLArea) = ()

shouldblock(block) = block && !haskey(ENV, "SYS_COMPILING")

function display_gui(win::GtkWidget; blocking=true)
    @async Gtk4.GLib.glib_main()
    if !isinteractive()
		signal_connect(_ -> exit(0), win, :close_request)
        shouldblock(blocking) && Gtk4.GLib.waitforsignal(win, :close_request)
    end
    Gtk4.focus(win)
	win
end

function display_gui(win::GLMakie.Screen; blocking=true, exit=true)
    if !isinteractive()
        shouldblock(blocking) && wait(win)
    end
    win
end

function GLMakie.correct_mouse(gla::GtkGLArea, w, h)
    fb = GLMakie.framebuffer_size(gla)
    s = Gtk4.scale_factor(gla)
    (w * s, fb[2] - (h * s))
end

function GLMakie.retina_scaling_factor(gla::GtkGLArea)
    f = Gtk4.scale_factor(gla)
    (f, f)
end

function calc_dpi(m::GdkMonitor)
    g = Gtk4.G_.get_geometry(m)
    wdpi = g.width / (Gtk4.G_.get_width_mm(m)/25.4)
    hdpi = g.height / (Gtk4.G_.get_height_mm(m)/25.4)
    min(wdpi, hdpi)
end

function Makie.window_area(scene::Scene, screen::GLMakie.Screen{T}) where T <: GtkGLArea
    area = scene.events.window_area
    dpi = scene.events.window_dpi
    signal_connect(
        function on_resize(a, w, h)
            m = Gtk4.monitor(a)
            dpi[] = calc_dpi(m)
            area[] = GeometryBasics.Rect2i(0, 0, w, h)
        end, screen.glscreen, :resize)
    Gtk4.queue_render(screen.glscreen)
end

function Makie.mouse_buttons(scene::Scene, gla::GtkGLArea)
    event = scene.events.mousebutton
    g = GtkGestureClick(gla, 0)

    function mousebuttonaction(con, n_press, x, y, action)
        button = Gtk4.G_.get_current_button(con)
        if button < 3
            event[] = MouseButtonEvent(Mouse.Button(Int(button)), Mouse.Action(Int(action)))
            Gtk4.queue_render(gla)
        end
    end

    signal_connect(g, "pressed") do con, n_press, x, y
        mousebuttonaction(con, n_press, x, y, true)
    end
    signal_connect(g, "released") do con, n_press, x, y
        mousebuttonaction(con, n_press, x, y, false)
    end
end

function Makie.mouse_position(scene::Scene, screen::GLMakie.Screen{T}) where T <: GtkGLArea
    gla = screen.glscreen
    g = Gtk4.GtkEventControllerMotion(gla)
    mouse_pos = scene.events.mouseposition
    mouse_entered = scene.events.entered_window
    hasfocus = scene.events.hasfocus

    signal_connect((c, x, y) -> mouse_pos[] = GLMakie.correct_mouse(gla, x, y), g, "motion")
    signal_connect((c, x, y) -> mouse_entered[] = true, g, "enter")
    signal_connect((c) -> mouse_entered[] = false, g, "leave")
end

function to_keybutton(c)
    v = Gtk4.G_.keyval_to_unicode(Gtk4.G_.keyval_to_upper(c))
    v != 0 && return Keyboard.Button(Int(v))

    Gtk4.KEY_uparrow == c && return Keyboard.up
    Gtk4.KEY_downarrow == c && return Keyboard.down
    Gtk4.KEY_rightarrow == c && return Keyboard.right
    Gtk4.KEY_leftarrow == c && return Keyboard.left
    Gtk4.KEY_Delete == c && return Keyboard.delete
    Gtk4.KEY_Escape == c && return Keyboard.escape

    return Keyboard.unknown
end

function Makie.scroll(scene::Scene, gla::GtkGLArea)
    scroll = scene.events.scroll
    e = GtkEventControllerScroll(Gtk4.EventControllerScrollFlags_HORIZONTAL | Gtk4.EventControllerScrollFlags_VERTICAL, gla)
    id = signal_connect((c, dx, dy) -> begin scroll[] = (dx, dy); return nothing end, e, "scroll")
end

function Makie.keyboard_buttons(scene::Scene, gla::GtkGLArea)
    keyboardbutton = scene.events.keyboardbutton
    e = GtkEventControllerKey(gla)

    function on_key(controller, keyval, keycode, state, pressed)
        keyboardbutton[] = KeyEvent(to_keybutton(keyval), Keyboard.Action(Int(pressed)))
        return true
    end

    signal_connect((con, v, code, s) -> on_key(con, v, code, s, true), e, "key-pressed")
    signal_connect((con, v, code, s) -> on_key(con, v, code, s, false), e, "key-released")
end

@guarded function refreshwindowcb(a, c, user_data)
    screen, fb_id = user_data
    screen.render_tick[] = nothing
    fb_id[] = glGetIntegerv(GL_FRAMEBUFFER_BINDING)
    GLMakie.render_frame(screen)
    return Cint(true)    
end

function GtkGLScreen(gla::GtkGLArea; reuse=false, screen_config...)
    Gtk4.auto_render(gla, false)
    Gtk4.signal_connect(function on_realize(a)
                            Gtk4.make_current(a)
                            e = Gtk4.get_error(a)
                            if e != C_NULL
                                @async println("Error during realize callback")
                                return
                            end
                        end, gla, "realize")
    
    ShaderAbstractions.switch_context!(gla)
    shader_cache = GLAbstraction.ShaderCache(gla)
    fb = GLMakie.GLFramebuffer((300, 300))
    fb_id = Ref(0)
    config = Makie.merge_screen_config(GLMakie.ScreenConfig, screen_config)
    config.render_on_demand = true
    gla.focusable = true

    postprocessors = [config.ssao ? ssao_postprocessor(fb, shader_cache) : empty_postprocessor()
                      config.fxaa ? fxaa_postprocessor(fb, shader_cache) : empty_postprocessor(), 
                      to_screen_postprocessor(fb, shader_cache, fb_id)]

    screen = GLMakie.Screen(
        gla, shader_cache, fb,
        config, false,
        nothing,
        Dict{WeakRef, GLMakie.ScreenID}(),
        GLMakie.ScreenArea[],
        Tuple{GLMakie.ZIndex, GLMakie.ScreenID, RenderObject}[],
        postprocessors,
        Dict{UInt64, RenderObject}(),
        Dict{UInt32, AbstractPlot}(),
        reuse)

    Gtk4.signal_connect(refreshwindowcb, gla, :render, Cint, (Ptr{Gtk4.Gtk4.GdkGLContext},), false, (screen, fb_id))
    time_per_frame = 1.0 / screen.config.framerate

    @async while isopen(screen) && !screen.stop_renderloop
		gla.context === nothing && (close(screen); return)						#Check if gla is destroyed
        ShaderAbstractions.switch_context!(gla)
        notify(screen.render_tick)

        t = time_ns()
        (!screen.config.pause_renderloop && GLMakie.requires_update(screen)) && Gtk4.queue_render(gla)
        t_elapsed = (time_ns() - t) / 1e9
        diff = time_per_frame - t_elapsed
        if diff > 0.001
            sleep(diff)
        else
            yield()
        end
    end

    screen
end

function GtkGLWindow(scene; resolution = (500, 500), screen_config...)
    config = Makie.merge_screen_config(GLMakie.ScreenConfig, screen_config)
    glArea = GtkGLArea()
    
    window = GtkWindow(config.title, resolution...)
    glArea.vexpand = glArea.hexpand = true
    window[] = glArea
    screen = GtkGLScreen(glArea)

    display(screen, scene)

    return (window, screen)
end

function Base.empty!(ax::Axis3)
    while !isempty(ax.scene.plots)
        delete!(ax.scene, ax.scene.plots[end])
    end
end