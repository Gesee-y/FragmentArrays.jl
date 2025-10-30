################################################################################################################################################
################################################################# INDEXING #####################################################################
################################################################################################################################################

function Base.getindex(f::FragmentVector, i)
	blockid = f.map[i]
	@boundscheck iszero(blockid) && throw(BoundsError(f, i))
	@inbounds return f.data[blockid][i - f.offset[blockid]]
end

function Base.setindex!(f::FragmentVector, v, i)
	blockid = f.map[i]
	if iszero(blockid)
		return insert!(f, i, v)
	end

	@inbounds f.data[blockid][i - f.offset[blockid]] = v
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
