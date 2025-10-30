# FragmentArrays.jl

Like sparse arrays but fragment into multiple arrays at deletion.

## Installation

For the stable version

```julia
julia> ]add FragmentArrays
```

## Features

**`FragmentVector`**, which acts as sparse vector but instead of just deleting an index from the mapping on deletion, it divide the array into 2 chunks and make that index invalid.

```julia
julia> a = FragmentVector(1,2,3)

julia> print(a.data)
[[1,2,3]]
julia> deleteat!(a, 2)

julia> print(a.data)
[[1],[3]]
```

If an element is added between to adjacent chunk, they are fused

```julia
julia> a = FragmentVector{Int}(undef, 3)

julia> a[1] = 1

julia> a[3] = 3

julia> print(a.data)
[[1],[3]]

julia> a[2] = 2

julia> print(a.data)
[[1,2,3]]
```

Getting data is an O(1) operation. The index first pass through a map to know in which fragment it belongs to, then is substrated by the fragment starting position to in the index in that fragment.
Benchmarks shows 2.7ns to access an element in a vector vs 3.9ns to access it in a FragmentVector)

## License

This package is under the MIT license. Feel free to do whatever you want with it.

## Contact

Email me at gesee37@gmail.com if necessary 