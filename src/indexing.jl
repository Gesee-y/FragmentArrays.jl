################################################################################################################################################
################################################################# INDEXING #####################################################################
################################################################################################################################################

export get_iterator, get_iterator_range, prealloc_range

const OFFSET_MASK = ((1 << 32)-1)
const BLOCK_MASK = ((1 << 32)-1) << 32

function Base.getindex(f::FragmentVector{T}, i)::T where T
	map = f.map
	@boundscheck 1 <= i <= length(map) || throw(BoundsError(f, i))
	
	@inbounds mask = map[i]
	@boundscheck iszero(mask) && error("The index [$i] doesn't exist or have been deleted")

	blockid, j = (mask) >> 32, i - (mask & OFFSET_MASK)
	
	return @inbounds f.data[blockid][j]
end

function Base.setindex!(f::FragmentVector, v, i)
	map = f.map
	@boundscheck 1 <= i <= length(map)
	
	mask = map[i]
	if iszero(mask)
		return insert!(f, i, v)
	end

    blockid, offset = (mask) >> 32, mask & OFFSET_MASK
	f.data[blockid][i - offset] = v
end

Base.size(f::FragmentVector) = (length(f),)
Base.size(f::FragmentVector, i) = size(f)[i]

Base.eachindex(f::FragIter) = eachindex(f.block)
Base.eachindex(f::FragIterRange) = eachindex(f.block)
Base.getindex(f::FragIter, i) = (f.block[i], f.ids[i])
Base.getindex(f::FragIter{T}, i) where T <: Tuple = (f.block[i]..., f.ids[i])
Base.getindex(f::FragIterRange, i) = (f.block[i], f.range[i])
function Base.iterate(f::FragIterRange, state=1)
    state > length(f.block) && return nothing
    return ((f.block[state], f.range[state]), state+1)
end
function Base.iterate(f::FragIter, state=1)
    state > length(f.block) && return nothing
    return ((f.block[state], f.ids[state]), state+1)
end
function Base.iterate(f::FragIter{T}, state=1) where T <: Tuple
    state > length(f.block) && return nothing
    return ((f.block[state]..., f.ids[state]), state+1)
end

function Base.iterate(f::FragmentVector{T}) where T
    return _iterate_fragment(f, 1, 1)
end

function Base.iterate(f::FragmentVector{T}, state) where T
    block, loc = state
    return _iterate_fragment(f, block, loc)
end

function _iterate_fragment(f::FragmentVector{T}, block::Int, loc::Int) where T
    while block <= length(f.data)
        blk = f.data[block]
        if loc <= length(blk)
            return (blk[loc], (block, loc + 1))
        else
            block += 1
            loc = 1
        end
    end
    return nothing
end


function get_iterator_range(f::FragmentVector{T}, vec; shouldsort=false) where T
    @inbounds begin
        if shouldsort
            sort!(vec)
        end

        result = FragIterRange{T}()
        l2 = length(vec)
        i = 1

        while i <= l2
            s = vec[i]
            m = f.map[s]

            if m != 0
                block = get_block(f, s)
                off = get_offset(f, s)
                start = vec[i] - off
                lenb = length(block)
                i += 1

                while i <= l2 && vec[i] - off <= lenb
                    i += 1
                end

                stop = vec[i-1] - off
                push!(result.block, block)
                push!(result.range, start:stop)
            else
                i += 1
            end
        end

        return result
    end
end

function get_iterator(f::FragmentVector{T, C}, vec; shouldsort=false) where {T, C}
    shouldsort && sort!(vec)
    l = length(f)
    l2 = length(vec)

    n = 0
    i = 1
    result = FragIter{C}()

    @inbounds while i <= l2
        s = vec[i]
        si = i
        block = get_block(f, s)
        off = get_offset(f, s)

        while i <= l2 && vec[i] - off <= length(block)
            i += 1
        end

        push!(result.block, block)
        push!(result.ids, vec[si:i-1] .- off)
    end

    return result
end

function get_iterator(fs::T, vec; shouldsort=false) where T <: Tuple
    shouldsort && sort!(vec)
    l2 = length(vec)

    n = 0
    i = 1
    result = FragIter{_to_vec_type(fs)}()

    @inbounds while i <= l2
        s = vec[i]
        si = i
        fix = Base.Fix2(get_block, s)
        blocks = fix.(fs)
        l = length(blocks[begin])
        off = get_offset(fs[begin], s)

        while i <= l2 && vec[i] - off <= l
            i += 1
        end

        push!(result.block, blocks)
        push!(result.ids, vec[si:i-1] .- off)
    end

    return result
end

function _to_vec_type(::T) where T

    return Tuple{_to_vec.(T.parameters)...}
end

_to_vec(::Type{<:FragmentVector{T, C}}) where {T, C} = C