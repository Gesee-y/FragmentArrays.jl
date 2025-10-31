################################################################################################################################################
################################################################# INDEXING #####################################################################
################################################################################################################################################

export get_iterator

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

function Base.iterate(f::FragmentVector{T}) where T
    return _iterate_fragment(f, 1, 1)
end

function Base.iterate(f::FragmentVector{T}, block::Int, local::Int=1) where T
    return _iterate_fragment(f, block, local)
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

        result = Vector{FragIter{T}}()
        l2 = length(vec)
        i = 1

        while i <= l2
            s = vec[i]
            block = get_block(f, s)
            off = get_offset(f, s)
            start = vec[i] - off
            lenb = length(block)
            i += 1

            while i <= l2 && vec[i] - off < lenb
                i += 1
            end

            stop = vec[i-1] - off
            push!(result, FragIterRange{T}(block, start:stop))
        end

        return result
    end
end

function get_iterator(f::FragmentVector{T}, vec; shouldsort=false) where T
    shouldsort && sort!(vec)
    l = length(f)
    l2 = length(vec)

    n = 0
    i = 1
    result = Tuple{Vector{T}, Vector{Int}}[]

    while i <= l2
        iter = Int[]
        s = vec[i]
        si = i
        block = get_block(f, s)
        off = get_offset(f, s)

        while i <= l2 && vec[i] - s < length(block)
            i += 1
        end

        append!(iter, vec[si:i] .- off)
        push!(result, FragIter{T}(block, iter))
    end

    return result
end