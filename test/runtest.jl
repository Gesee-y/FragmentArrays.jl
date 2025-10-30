include(joinpath("..", "src", "FragmentArrays.jl"))

using .FragmentArrays

a = FragmentVector{Int}(undef, 10)

a[5] = 1
a[3] = 2
println(a.data)
println(a.offset)
println(a.map)
println(a[3])
a[4] = 3
println(a.data)
println(a.offset)
println(a.map)