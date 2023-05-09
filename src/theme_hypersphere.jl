export theme_hypersphere

function theme_hypersphere()
    Theme(
        backgroundcolor = :grey10,
        textcolor = :white,
        linecolor = :gray60,
        Axis = (
            backgroundcolor = :grey,
            xgridcolor = (:white, 0.35),
            ygridcolor = (:white, 0.35),
            leftspinevisible = false,
            rightspinevisible = false,
            bottomspinevisible = false,
            topspinevisible = false,
            xminorticksvisible = false,
            yminorticksvisible = false,
            xticksvisible = false,
            yticksvisible = false,
            xlabelpadding = 3,
            ylabelpadding = 3
        ),
        Legend = (
            framevisible = false,
            padding = (0, 0, 0, 0),
        ),
        Axis3 = (
            xgridcolor = (:white, 0.35),
            ygridcolor = (:white, 0.35),
            zgridcolor = (:white, 0.35),
            xspinesvisible = false,
            yspinesvisible = false,
            zspinesvisible = false,
            xticksvisible = false,
            yticksvisible = false,
            zticksvisible = false,
        ),
        Colorbar = (
            ticksvisible = false,
            spinewidth = 0,
            ticklabelpad = 5,
        )
    )
end