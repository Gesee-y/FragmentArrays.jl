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
	blockid, offset = (mask) >> 32, mask & OFFSET_MASK
	
	if iszero(mask)
		return insert!(f, i, v)
	end

	f.data[blockid][i - offset] = v
end

Base.size(f::FragmentVector) = (length(f),)
Base.size(f::FragmentVector, i) = size(f)[i]

function Base.iterate(f::FragmentVector)
	state = f.offset[begin]+1
	return (f.data[begin][state],state+1)
end

function Base.iterate(f::FragmentVector, state)
	id = f.map[state]

	if iszero(id)
		id = id+1
		id > length(f.data) && return nothing
		state = f.offset[id] + 1
	end
	
	return (f.data[id][state],state+1)
end

function get_iterator(f::FragmentVector{T}, vec) where T
	sort!(vec)
	l = length(f)
	l2 = length(vec)

	n = 0
	i = 1
	result = Tuple{Vector{T}, Vector{Int}}[]

	while i < l && i < l2
		iter = Int[]
		s = vec[i]
		block = get_block(f, s)
		off = get_offset(f, s)

		while i <= l2 && vec[i] - s < length(block)
			push!(iter, vec[i] - off)
			i += 1
		end

		push!(result, (block, iter))
	end

	return result
end