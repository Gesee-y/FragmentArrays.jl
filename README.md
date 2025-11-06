# FragmentArrays.jl

![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

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
julia> a = FragmentVector{Int}()

julia> a[1] = 1

julia> a[3] = 3

julia> println(a)
[1, ., 3]

julia> println(a.data)
[[1],[3]]

julia> a[2] = 2

julia> print(a.data)
[[1,2,3]]
```

you can also use `prealloc_range` to allocate a new block of data so later insertion won't allocate new structures.

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

`FragmentVector`s also support multiple layout for fragments. This means that chunks may not necessarily be a `Vector`. Then can be anything that overload the necessary interface.
For example using StructArrays.jl wen can do

```julia

struct SoALayout{T} <: AbstractArrayLayout{T}
    data::StructVector{T}
end
```

and just do:

```julia

struct Position
    x::Int
end

a = FragmentVector{Int, SoALayout}()

a[1] = Position(1)
a[2] = Position(2)

for (blk, ids) in get_iterator(a, [1, 2])
    x = blk.data.x
    for i in ids
        x[i] += 1
    end
end
```

You can also create new indexing style. This way in your specific context, you can make random access O(1) instead of O(log n)

## Performance trade-offs

| Operation              | Complexity | Notes |
|------------------------|-------------|-------|
| Random access          | O(log n) n is the number of fragments      | A bit slower than `Vector` due to indirection `2.7 ns` vs `3.1 ns`|
| Iteration              | O(n)      | Faster when iterating contiguous ranges |
| Insertion/Deletion     | ~O(1) amortized | No large-scale data shifting |
| Memory usage           | Low       | Freed fragments release memory immediately |

## Use cases 

This package is particularly suitable when you need:

- **Sparse but efficient contiguous iterations**
- **Data groups as ranges**: Group of data can be made as a range which will have his own block and can be more efficiently iterated
- **Multiple arrays** but stable indexing between them
- **Fast array's element insertion/deletion**

## License

This package is under the MIT license. Feel free to do whatever you want with it.

## Contact

Email me at gesee37@gmail.com if necessary 