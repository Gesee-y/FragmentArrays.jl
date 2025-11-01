# FragmentArrays.jl

Like sparse arrays but fragment into multiple arrays at deletion.

## Installation

For the stable version

```julia
julia> ]add FragmentArrays
```

## Features

**`FragmentVector`**, which acts as sparse vector but instead of just deleting an index from the mapping on deletion, it divide the array into 2 chunks and make that index invalid.

```julia-repl 
julia> a = FragmentVector(1,2,3)

julia> print(a.data)
[[1,2,3]]
julia> deleteat!(a, 2)

julia> print(a.data)
[[1],[3]]
```

If an element is added between to adjacent chunk, they are fused

```julia-repl 
julia> a = FragmentVector{Int}(undef, 3)

julia> a[1] = 1

julia> a[3] = 3

julia> print(a.data)
[[1],[3]]

julia> a[2] = 2

julia> print(a.data)
[[1,2,3]]
```

you can also use `prealloc_range` to allocate a new block of data

Unlike sparse set, you can create iterators to efficiently iterate on a specific set of index.

```julia-repl 
julia> a = FragmentVector(1,2,3,4)

julia> iter = get_iterator(a, [1,3,4])

julia> for (block, ids) in iter
           for i in ids
               println(block[i])
           end
       end

1
3
4
```

Getting data is an O(1) operation. The index first pass through a map to know in which fragment it belongs to, then is substrated by the fragment starting position to in the index in that fragment.
Benchmarks shows 2.7ns to access an element in a vector vs 3.9ns to access it in a FragmentVector)

## Use cases 

This package is particularly suitable when you need:

- **Sparcity and efficient iterations**
- **Groups as intervals**: Group of data can be made as a range which will have his own block and can be more efficiently iterated
- **Multiple arrays** but stable indexing between them
- **Fast arrays insertion/deletion**

## License

This package is under the MIT license. Feel free to do whatever you want with it.

## Contact

Email me at gesee37@gmail.com if necessary 