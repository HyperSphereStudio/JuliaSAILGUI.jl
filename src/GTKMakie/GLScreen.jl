const ScreenType = GLMakie.Screen{GtkGLAreaLeaf}

mutable struct ScreenState
    screen::ScreenType
    fb_id::Ref{Int}
    realize_count::Int
end

const SCREEN_STATES = Dict{Ptr{Gtk4.GtkGLArea}, ScreenState}()

glaptr(gla) = glaptr(gla.handle)
glaptr(gla::Ptr) = Ptr{GtkGLArea}(gla)
getscreenstate(gla) = SCREEN_STATES[glaptr(gla)]
hasscreenstate(gla) = haskey(SCREEN_STATES, glaptr(gla))

function GtkGLScreen(gla; screen_config...)
	screen_config = Makie.merge_screen_config(GLMakie.ScreenConfig, Dict{Symbol, Any}(screen_config...))
    screen_config.render_on_demand = true

    Gtk4.auto_render(gla, false)
    Gtk4.on_realize(on_gla_realize, gla, screen_config)
    Gtk4.on_unrealize(on_gla_unrealize, gla)
	Gtk4.on_render(on_gla_render, gla)
	
	gla
end

Base.display(gla::GtkGLArea, scene; attr...) = @idle_add begin 
    Makie.update_state_before_display!(scene)
    display(getscreenstate(gla).screen, scene; attr...)
end

function GtkGLWindow(scene, display_attributes...; resolution = (500, 500), screen_config...)
    screen_config = Makie.merge_screen_config(GLMakie.ScreenConfig, Dict{Symbol, Any}(screen_config))
    
    window = GtkWindow(screen_config.title, resolution...)
    gla = GtkGLScreen(GtkGLArea(vexpand=true, hexpand=true))
    window[] = gla
    display(gla, scene; display_attributes...)

    return window
end

function display_gui(win::GtkWidget; blocking=true)
    if !isinteractive()
		@async Gtk4.GLib.glib_main()
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

shouldblock(block) = block && !haskey(ENV, "SYS_COMPILING")

function Base.resize!(screen::ScreenType, w::Int, h::Int)
	window = GLMakie.to_native(screen)
    (w > 0 && h > 0 && isopen(window)) || return nothing
    
    ShaderAbstractions.switch_context!(window)
    winscale = screen.scalefactor[] / Gtk4.scale_factor(window)
    winw, winh = round.(Int, winscale .* (w, h))

    fbscale = screen.px_per_unit[]
    fbw, fbh = round.(Int, fbscale .* (w, h))
    resize!(screen.framebuffer, fbw, fbh)
end

function Makie.window_area(scene::Scene, screen::ScreenType)
	gl = screen.glscreen
    winscale = screen.scalefactor[] / Gtk4.scale_factor(gl)
    area = scene.events.window_area
    dpi = scene.events.window_dpi
	Gtk4.on_resize(_glarea_resize_cb, gl, (dpi, area, winscale))
    Gtk4.queue_render(screen.glscreen)
end
Makie.disconnect!(screen::ScreenType, ::typeof(window_area)) = ()

function _glarea_resize_cb(aptr, w, h, user_data)
    dpi, area, winscale = user_data
    a = convert(GtkGLArea, aptr)
    m = Gtk4.monitor(a)
    if m !== nothing
        dpi[] = calc_dpi(m)
    end
    winw, winh = round.(Int, (w, h) ./ winscale )
    area[] = Recti(minimum(area[]), winw, winh)
    nothing
end

@guarded function on_gla_render(gla, c, user_data)
    if hasscreenstate(gla)
        ss = getscreenstate(gla)
        ss.screen.render_tick[] = nothing
        ss.fb_id[] = glGetIntegerv(GL_FRAMEBUFFER_BINDING)
        GLMakie.render_frame(ss.screen)
    end
	return Cint(true)
end

@guarded function on_gla_realize(ptr, user_data)
    if hasscreenstate(ptr)
        getscreenstate(ptr).realize_count += 1
    else
        @idle_add begin
            try 
                gla = convert(GtkGLArea, ptr)
                screen_config = user_data
                shader_cache = GLAbstraction.ShaderCache(gla)
                ShaderAbstractions.switch_context!(gla)
                fb = GLMakie.GLFramebuffer((500, 500))
                fb_id = Ref(0)
    
                postprocessors = [screen_config.ssao ? GLMakie.ssao_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
                                  screen_config.oit ? GLMakie.OIT_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(),
                                  screen_config.fxaa ? GLMakie.fxaa_postprocessor(fb, shader_cache) : GLMakie.empty_postprocessor(), 
                                  GLMakie.to_screen_postprocessor(fb, shader_cache, fb_id)]
                    
                screen = GLMakie.Screen(
                    gla, shader_cache, fb,
                    screen_config, false,
                    nothing,
                    Dict{WeakRef, GLMakie.ScreenID}(),
                    GLMakie.ScreenArea[],
                    Tuple{GLMakie.ZIndex, GLMakie.ScreenID, GLMakie.RenderObject}[],
                    postprocessors,
                    Dict{UInt64, GLMakie.RenderObject}(),
                    Dict{UInt32, Makie.AbstractPlot}(),
                    false,
                )
        
                screen.scalefactor[] = !isnothing(screen_config.scalefactor) ? screen_config.scalefactor : Gtk4.scale_factor(gla)
                screen.px_per_unit[] = !isnothing(screen_config.px_per_unit) ? screen_config.px_per_unit : screen.scalefactor[]
    
                SCREEN_STATES[glaptr(gla)] = ScreenState(screen, fb_id, 1)
                Gtk4.queue_render(gla)
            catch e
                showerror(stdout, e)
                throw(e)
            end
        end
    end
    

    nothing
end

@guarded function on_gla_unrealize(gla, glaObject)
    if hasscreenstate(gla)
        try
            ss = getscreenstate(gla)
            ss.realize_count -= 1
            if ss.realize_count == 0

                screen = ss.screen
                GLMakie.set_screen_visibility!(screen, false)
                GLMakie.stop_renderloop!(screen; close_after_renderloop=false)
                empty!(screen)
                GLMakie.set_screen_visibility!(screen, false)

                delete!(SCREEN_STATES, glaptr(gla))
            end
        catch e
            showerror(stdout, e)
            throw(e)
        end
    end
    nothing
end