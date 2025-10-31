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

@inline function decode_mask(mask::UInt64)
    blockid = Int(mask >> 32)
    start   = Int(mask & OFFSET_MASK)
    return blockid, start
end

@inline function make_mask(blockid::Int, start::Int)
    return (UInt64(blockid) << 32) | UInt64(start & Int(OFFSET_MASK))
end

function _bump_block_starts!(map::Vector{UInt64}, from_index::Int)
    
    @inbounds for k in 1:length(map)
        m = map[k]
        if m != 0
            
            s = Int(m & OFFSET_MASK)
            if s >= from_index
                
                high = m & ~OFFSET_MASK
                newlow = UInt64(s + 1) & OFFSET_MASK
                map[k] = high | newlow
            end
        end
    end
    return
end

function Base.insert!(f::FragmentVector{T}, i::Int, v::T) where T
    map = f.map
    lmap = length(map)
    @boundscheck 1 <= i <= lmap || throw(BoundsError(f, i))

    mask = map[i]
    if mask != 0
        
        bid, bstart = decode_mask(mask)
        local = i - bstart
        @inbounds begin
            insert!(f.data[bid], local, v)    
            _bump_block_starts!(map, i)
            
        end
        return
    end

    left_exists = (i > 1 && map[i-1] != 0)
    right_exists = (i < lmap && map[i+1] != 0)

    if left_exists && right_exists
        
        lmask = map[i-1]; rmask = map[i+1]
        lbid, lstart = decode_mask(lmask)
        rbid, rstart = decode_mask(rmask)

        
        if lbid == rbid
            
            local = i - lstart
            @inbounds insert!(f.data[lbid], local, v)
            _bump_block_starts!(map, i)
            return
        end

        
        left_block = f.data[lbid]
        right_block = f.data[rbid]

        
        if i == lstart + length(left_block)
            
            push!(left_block, v)
            
            map[i] = make_mask(lbid, lstart)
            _bump_block_starts!(map, i+1)  
            return
        elseif i == rstart - 1
            
            insert!(right_block, 1, v)
            map[i] = make_mask(rbid, rstart - 1)
            _bump_block_starts!(map, i+1)
            return
        else
            
            nbid = length(f.data) + 1
            push!(f.data, Vector{T}([v]))
            map[i] = make_mask(nbid, i - 1)
            _bump_block_starts!(map, i+1)
            return
        end
    elseif left_exists
        
        lmask = map[i-1]
        lbid, lstart = decode_mask(lmask)
        left_block = f.data[lbid]
        if i == lstart + length(left_block)
            push!(left_block, v)
            map[i] = make_mask(lbid, lstart)
            _bump_block_starts!(map, i+1)
            return
        else
            
            nbid = length(f.data) + 1
            push!(f.data, Vector{T}([v]))
            map[i] = make_mask(nbid, i - 1)
            _bump_block_starts!(map, i+1)
            return
        end
    elseif right_exists
        
        rmask = map[i+1]
        rbid, rstart = decode_mask(rmask)
        right_block = f.data[rbid]
        if i == rstart - 1
            insert!(right_block, 1, v)
            
            newstart = rstart - 1
            @inbounds for k in 1:length(map)
                m = map[k]
                if m != 0
                    b, s = decode_mask(m)
                    if b == rbid
                        
                        map[k] = make_mask(b, newstart)
                    end
                end
            end
            _bump_block_starts!(map, i+1)
            return
        else
            nbid = length(f.data) + 1
            push!(f.data, Vector{T}([v]))
            map[i] = make_mask(nbid, i - 1)
            _bump_block_starts!(map, i+1)
            return
        end
    else
        
        nbid = length(f.data) + 1
        push!(f.data, Vector{T}([v]))
        map[i] = make_mask(nbid, i - 1)
        _bump_block_starts!(map, i+1)
        return
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