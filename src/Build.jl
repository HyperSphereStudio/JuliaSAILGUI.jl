using Pkg

Pkg.activate(".")

println("Resolve Packages [y\n]?:")

readline() == "y" && begin
  try Pkg.rm("mousetrap") catch end
  try Pkg.rm("mousetrap_windows_jll") catch end
  try Pkg.rm("mousetrap_linux_jll") catch end
  try Pkg.rm("mousetrap_apple_jll") catch end
  try Pkg.rm("libmousetrap_jll") catch end
  try Pkg.rm("MousetrapMakie") catch end
  #Pkg.gc()
  Pkg.add(url="https://github.com/clemapfel/mousetrap.jl")
  Pkg.add(url="https://github.com/clemapfel/mousetrap_jll")
  Pkg.add(url="https://github.com/clemapfel/MousetrapMakie.jl")
  Pkg.resolve()
end

println("Precompiling...")
Pkg.precompile()
