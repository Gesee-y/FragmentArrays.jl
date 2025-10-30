include(joinpath("..", "src", "FragmentArrays.jl"))

using .FragmentArrays

a = FragmentVector(1,2,3)

println(a)