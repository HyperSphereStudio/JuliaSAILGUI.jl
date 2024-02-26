using Pkg

Pkg.activate(".")

println("Resolve Packages [y\n]?:")

readline() == "y" && Pkg.resolve()

println("Precompiling...")
Pkg.precompile()
