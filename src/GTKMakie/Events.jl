Makie.window_open(scene::Scene, ::GtkGLArea) = scene.events.window_open[] = true
Makie.disconnect!(screen::ScreenType, ::typeof(Makie.window_open)) = ()
Makie.hasfocus(scene::Scene, ::GtkGLArea) = scene.events.hasfocus[] = true
Makie.unicode_input(::Scene, ::GtkGLArea) = ()
Makie.dropped_files(::Scene, ::GtkGLArea) = ()
Makie.entered_window(::Scene, ::GtkGLArea) = ()
Makie.disconnect!(screen::ScreenType, ::T) where T <: Function = ()

function Makie.mouse_buttons(scene::Scene, gla::GtkGLArea)
    event = scene.events.mousebutton
    g = GtkGestureClick(gla, 0)
	
	Gtk4.on_pressed(_mouse_event_cb, g, (event, Mouse.press))
	Gtk4.on_released(_mouse_event_cb, g, (event, Mouse.release))
end

function Makie.keyboard_buttons(scene::Scene, gla::GtkGLArea)
	event = scene.events.keyboardbutton
    e = GtkEventControllerKey(gla)
	Gtk4.on_key_pressed(_key_pressed_cb, e, event)
	Gtk4.on_key_released(_key_released_cb, e, event)
end

function Makie.mouse_position(scene::Scene, screen::ScreenType)
    gla = screen.glscreen
    g = Gtk4.GtkEventControllerMotion(gla)
    event = scene.events.mouseposition
    hasfocus = scene.events.hasfocus
    entered = scene.events.entered_window

	Gtk4.on_motion(_mouse_motion_cb, g, (hasfocus, event))
	Gtk4.on_enter(_mouse_enter_cb, g, entered)
	Gtk4.on_leave(_mouse_leave_cb, g, entered)
end
Makie.disconnect!(screen::ScreenType, ::typeof(Makie.mouse_position)) = ()

function Makie.scroll(scene::Scene, gla::GtkGLArea)
	event = scene.events.scroll
    e = GtkEventControllerScroll(Gtk4.EventControllerScrollFlags_HORIZONTAL | Gtk4.EventControllerScrollFlags_VERTICAL, gla)
    id = Gtk4.on_scroll(_scroll_cb, e, (event, gla))
end

function _scroll_cb(ptr, dx, dy, user_data)
    event, window = user_data
    event[] = (dx, dy)
    Gtk4.queue_render(window)
    Cint(0)
end

function _mouse_motion_cb(ptr, x, y, user_data)
    ec = convert(GtkEventControllerMotion, ptr)
    glarea = Gtk4.widget(ec)
    hasfocus, event = user_data
    if hasfocus[]
        event[] = GLMakie.correct_mouse(glarea, x,y)
        Gtk4.queue_render(glarea)
    end
    nothing
end

function _mouse_enter_cb(ptr, x, y, entered)
    entered[] = true
    nothing
end

function _mouse_leave_cb(ptr, entered)
    entered[] = false
    nothing
end

function _mouse_event_cb(ptr, n_press, x, y, user_data)
    event, event_type = user_data
    controller = convert(GtkEventController, ptr)
    glarea = Gtk4.widget(controller)
    b = Gtk4.current_button(controller)
    b > 3 && return nothing
    event[] = MouseButtonEvent(_translate_mousebutton(b), event_type)
    Gtk4.queue_render(glarea)
    nothing
end

function _key_pressed_cb(ptr, keyval, keycode, state, event)
    event[] = KeyEvent(Keyboard.Button(_translate_keyval(keyval)), Keyboard.Action(Int(1)))
    Cint(0)
end

function _key_released_cb(ptr, keyval, keycode, state, event)
    event[] = KeyEvent(Keyboard.Button(_translate_keyval(keyval)), Keyboard.Action(Int(0)))
    nothing
end

function _translate_mousebutton(b)
    if b==1
        return Mouse.left
    elseif b==3
        return Mouse.right
    elseif b==2
        return Mouse.middle
    else
        return Mouse.none
    end
end

function _translate_keyval(c)
    if c>0 && c<=96 # letters - corresponding Gdk codes are uppercase, which implies shift is also being pressed I think
        return Int(c)
    elseif c>=97 && c<=122
        return Int(c-32) # this is the lowercase version
    elseif c==65507 # left control
        return Int(341)
    elseif c==65508 # right control
        return Int(345)
    elseif c==65505 # left shift
        return Int(340)
    elseif c==65506 # right shift
        return Int(344)
    elseif c==65513 # left alt
        return Int(342)
    elseif c==65514 # right alt
        return Int(346)
    elseif c==65361 # left arrow
        return Int(263)
    elseif c==65364 # down arrow
        return Int(264)
    elseif c==65362 # up arrow
        return Int(265)
    elseif c==65363 # right arrow
        return Int(262)
    elseif c==65360 # home
        return Int(268)
    elseif c==65365 # page up
        return Int(266)
    elseif c==65366 # page down
        return Int(267)
    elseif c==65367 # end
        return Int(269)
    elseif c==65307 # escape
        return Int(256)
    elseif c==65293 # enter
        return Int(257)
    elseif c==65289 # tab
        return Int(258)
    elseif c==65535 # delete
        return Int(261)
    elseif c==65388 # backspace
        return Int(259)
    elseif c==65379 # insert
        return Int(260)
    elseif c>=65470 && c<= 65481 # function keys
        return Int(c-65470+290)
    end
    return Int(-1) # unknown
end