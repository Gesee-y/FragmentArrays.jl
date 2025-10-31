#####################################################################################################################
###################################################### OPERATIONS ###################################################
#####################################################################################################################

export prealloc_range, get_block, get_offset

function Base.push!(f::FragmentVector, v)
    id = length(f.data)
	
	push!(f.map, id)
	push!(f.data[id], v)
end

function Base.append!(f::FragmentVector, v)
	id = length(f.data)
	map = f.map

	m = 0
	while iszero(map[m])
		m -= 1
	end

    mask = map[m]
	id, offset = (mask >> 32) & BLOCK_MASK, mask & offset

	ls = length(map)
	le = _length(v)
	
	resize!(map, ls+le)
    for i in ls+1:ls+le
    	map[i] = id << 32 | offset
    end

	append!(f.data[id], v)
end

function Base.insert!(f::FragmentVector, i, v)
	map = f.map
	mask = f.map[i]

	if iszero(mask)
		if 1 < i < length(map)
			ml, mr = map[i-1], map[i+1]
			cl,cr = iszero(ml), iszero(mr)

			left = ml >> 32
			right = mr >> 32

			if cl && cr
				blockid = max(_search_index(f.map, i) >> 32, 1)
			    insert!(f.data, blockid, [v])
			    map[i] = blockid << 32 | i-1
			    @inbounds for j in i+1:length(map)
			 	    map[j] += (1*iszero(map[j])) << 32
				end
				
				return
			end

			if iszero(left)
				map[i] = mr
				block = f.data[right]
				map[i:i+length(block)+1] .+= 1

				pushfirst!(block, v)
			elseif iszero(right)
				map[i] = ml
				block = f.data[left]

				push!(block, v)
			else
				bl, br = f.data[left], f.data[right]
				map[i] = left
				push!(bl, v)
				offset = mr & OFFSET_MASK
				noffset = ml & OFFSET_MASK

				_fuse_block!(bl, br, map, left, offset, noffset)
				_deleteat!(f.data, right)
			end
		else
			l = length(map)

			if l == 1
				map[l] = 1
				push!(f.data, [v])
			end
			if i == 1
				map[i] = 1
				if iszero(map[i+1])
					pushfirst!(f.data, [v])
					@inbounds for j in 2:l
					    map[j] += (1 * !iszero(map[j])) << 32
					end
				else
					pushfirst!(f.data[1], v)
				end
			else
				id = length(f.data)
				map[i] = id << 32 | i-1

				if iszero(map[i-1])
					push!(f.data, [v])
				else
					push!(f.data[end], v)
				end
			end
		end
	else
		id, offset = (mask) >> 32, mask & OFFSET_MASK
	    dl = length(f.data[id])
	
		insert!(f.data[id], i, v)
		insert!(map, i, id)
		
		for i in offset+dl:length(map)
			map[i] += 1 * iszero(map[i])
		end
	end
end 

function Base.pop!(f::FragmentVector)
	f.map[end] = 0
	r = pop!(f.data[end])

	if isempty(f.data[end])
		pop!(f.data)
	end

	return r
end

function Base.deleteat!(f::FragmentVector, i)
	map = f.map
	mask = map[i]
	if iszero(mask)
		return 
	end

	id, offset = (value & BLOCK_MASK) >> 32, value & OFFSET_MASK
	map[i] = 0

	idx = i - offset

	if idx == 1
		f.data[id] = f.data[id][2:end]
	elseif idx == length(f.data[id])
		pop!(f.data[id])
	else
		v = f.data[id]
		vr = v[idx+1:end]
		resize!(v, idx-1)
		insert!(f.data, id+1, vr)

		map[i+1:i+length(vr)] .= id+1 << 32 | i-1
	end

	if isempty(f.data[id])
		_deleteat(f.data, id)

		for j in i+1:l
			if !iszero(map[j])
				map[j] -= 1
			end
		end
	end
end

function Base.resize!(f::FragmentVector, n)
	l = length(f)
	map = f.map

	n == l && return
	resize!(map, n)

	if n > l
		for i in l+1:n
			map[i] = 0
		end
	else
		j = length(f.offset)
		while !isempty(f.offset) && f.offset[end] > n
			pop!(f.offset)
			pop!(f.data)
		end
	end
end

function Base.length(f::FragmentVector)
	l = 0
	for v in f.data
		l += length(v)
	end

	return l
end

function prealloc_range(f::FragmentVector{T}, r::UnitRange) where T
	blockid = max(_search_index(f.map, r[begin]) >> 32, 1)
	last = r[end]
	map = f.map

	if last > length(map)
		resize!(map, last)
	end
	map[r] .= blockid << 32 | r[begin]-1
	insert!(f.data, blockid, Vector{T}(undef, length(r)))
end

function get_block(f::FragmentVector{T}, i) where T
	id = f.map[i]
	return f.data[(id >> 32)]
end
function get_offset(f::FragmentVector, i)
	id = f.map[i]
	return id & OFFSET_MASK
end

###################################################### HELPERS ######################################################

_length(v::AbstractVector) = length(v)
_length(v::Tuple) = length(v)
_length(n) = 1

function _fuse_block!(dest, src, map, dest_id, offset, noffset)
	l1 = length(dest)
	l2 = length(src)
	append!(dest, src)

	@inbounds for i in offset:offset+l2
		map[i] = dest_id << 32 | noffset
	end
end

function _search_index(map, i)
	isempty(map) && return 0

	m = min(i, length(map))

	while m > 0 && iszero(map[m]) 
		m -= 1
	end

	iszero(m) && return m
	return map[m]
end 

function _deleteat!(v, i)
	l = length(v)

	if i == l
		pop!(v)
	else
		v[i] = v[i+1]

		for j in i+1:l-1
			v[j] = v[j+1]
		end

		pop!(v)
	end
end

_isvalid(map, i) = iszero(map, i)