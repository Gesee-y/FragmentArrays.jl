#####################################################################################################################
###################################################### OPERATIONS ###################################################
#####################################################################################################################

export prealloc_range!, get_block, get_offset, numelt, get_block_and_offset

Base.length(f::FragmentVector) = length(f.map)
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

@inline function make_mask(blockid, start)
    return (UInt64(blockid) << 32) | UInt64(start & Int(OFFSET_MASK))
end

function _bump_block_starts!(map::Vector{UInt64}, from_index::Int)
    
    @inbounds for k in 1:length(map)
        m = map[k]
        if m != 0
            
            s = Int(m & OFFSET_MASK)
            if s >= from_index
                map[k] += 1
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
        lcl = i - bstart
        @inbounds begin
            insert!(f.data[bid], lcl, v)
            insert!(map, i, mask)    
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
        
        left_block = f.data[lbid]
        right_block = f.data[rbid]

        map[i:i+length(right_block)] .= lmask
        push!(left_block, v)

        _fuse_block!(left_block, right_block)
        _deleteat!(f.data, rbid)

        for j in 1:length(map)
            m = map[j]
            bid, m = decode_mask(m)
            map[j] -= (1 << 32)*(bid >= rbid)
        end

    elseif left_exists
        lmask = map[i-1]
        lbid, lstart = decode_mask(lmask)
        map[i] = lmask
        push!(f.data[lbid], v)

    elseif right_exists
        rmask = map[i+1]
        map[i] = rmask
        rbid, rstart = decode_mask(rmask)
        right_block = f.data[rbid]
        pushfirst!(right_block, v)
        map[i:i+length(right_block)-1] .-= 1

    else
        nbid = length(f.data) + 1
        push!(f.data, Vector{T}([v]))
        map[i] = make_mask(nbid, i - 1)
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
    data = f.data
	if iszero(mask)
		return 
	end

	id, offset = decode_mask(mask)
    blk = data[id]
	map[i] = 0

	idx = i - offset

	if idx == 1
		f.data[id] = blk[2:end]
        map[i+1:i+length(blk)-1] .+= 1
	elseif idx == length(blk)
		pop!(blk)
	else
		vr = blk[idx+1:end]
		resize!(blk, idx-1)
		push!(data, vr)

        new_mask = make_mask(length(data), i)

		map[i+1:i+length(vr)] .= new_mask
	end

	if isempty(f.data[id])
		_deleteat!(f.data, id)

		for j in 1:length(map)
            m = map[j]
            bid, m = decode_mask(m)
			map[j] -= (1 << 32)*(bid >= id)
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
Base.isempty(f::FragmentVector) = isempty(f.map)

function numelt(f::FragmentVector)
	l = 0
	for v in f.data
		l += length(v)
	end

	return l
end

function prealloc_range!(f::FragmentVector{T}, r::UnitRange{Int}) where T
    map = f.map
    length(map) < r[end] && resize!(f, r[end])
    length(r) < 1 && return r
    lmap = length(map)

    rstart = max(first(r), 1)
    rend = min(last(r), lmap)
    rmask, lmask = map[rstart], map[rend]

    while rstart <= rend && rmask != 0
        rstart += 1
        rmask = map[rstart]
    end
    while rstart <= rend && lmask != 0
        rend -= 1
        lmask = map[rend]
    end

    if rstart > rend
        return rstart:rstart-1  
    end

    rmask, lmask = map[max(rstart-1, 1)], map[min(rend+1, lmap)]

    if rmask != 0 && lmask != 0
    	bid, off = decode_mask(rmask)
    	rid, _ = decode_mask(lmask)
    	rblk = f.data[bid]
    	resize!(rblk, rend-off)
    	append!(rblk, f.data[rid])
    	_deleteat!(f.data, rid)
    	map[off+1:off+length(rblk)] .= rmask
    	return rstart:rend
    elseif rmask != 0
    	bid, off = decode_mask(rmask)
    	rblk = f.data[bid]
    	resize!(rblk, rend-off)
    	map[off+1:off+length(rblk)] .= rmask
    	return rstart:rend
    elseif lmask != 0
    	v = Vector{T}(undef, rend-rstart+1)
    	bid, off = decode_mask(lmask)
    	lblk = f.data[bid]
    	append!(v, lblk)
    	f.data[bid] = v
    	lmask = make_mask(bid, rstart-1)
    	map[rstart:rend] .= lmask
    	return rstart:rend
    end

    new_block = Vector{T}(undef, rend - rstart + 1)
    push!(f.data, new_block)
    blockid = length(f.data)

    mask = make_mask(blockid, rstart-1)
    @inbounds for i in rstart:rend
        map[i] = mask
    end

    return rstart:rend
end

function get_block(f::FragmentVector{T}, i) where T
	id = f.map[i]
	return f.data[(id >> 32)]
end
function get_offset(f::FragmentVector, i)
	id = f.map[i]
	return id & OFFSET_MASK
end
function get_block_and_offset(f::FragmentVector, i)
	id = f.map[i]
	return f.data[(id >> 32)], id & OFFSET_MASK
end

###################################################### HELPERS ######################################################

_length(v::AbstractVector) = length(v)
_length(v::Tuple) = length(v)
_length(n) = 1

function _fuse_block!(dest, src)
	append!(dest, src)
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

	if i != l
		v[i] = v[i+1]

		for j in i+1:l-1
			v[j] = v[j+1]
		end
    end

	pop!(v)
end

_isvalid(map, i) = iszero(map, i)