#####################################################################################################################
###################################################### OPERATIONS ###################################################
#####################################################################################################################

function Base.push!(f::FragmentVector, v)
    id = length(f.data)
	push!(f.map, id)
	push!(f.data[id], v)
end

function Base.append!(f::FragmentVector, v)
	id = length(f.data)
	map = f.map

	ls = length(map)
	le = _length(v)
	
	resize!(map, ls+le)
    for i in ls+1:ls+le
    	map[i] = id
    end

	append!(f.data[id], v)
end

function Base.insert!(f::FragmentVector, v, i)
	map = f.map
	id = f.map[i]

	if iszero(id)
		if 1 < i < length(map)
			left, right = map[i-1], map[i+1]
			cl,cr = iszero(left), iszero(right)

			if cl && cr
				blockid = _search_index(f.offset, i)
				insert!(f.data, [v])
				map[i] = blockid
				@inbounds for j in i+1:length(map)
					if !iszero(map[j])
						map[j] += 1
					end
				end

				return
			end

			if iszero(left)
				map[i] = right
				block = f.data[right]

				pushfirst!(block, v)
			elseif iszero(right)
				map[i] = left
				block = f.data[left]

				push!(block, v)
			else
				bl, br = f.data[left], f.data[right]
				push!(bl, v)
				offset = f.offset[right]

				_fuse_block!(bl, br, map, left, offset)
			end
		else
			l = length(map)

			if l == 1
				map[l] = 1
				f.offset[l] = 0
				push!(f.data, [v])
			end
			if i == 1
				map[i] = 1
				if iszero(map[i+1])
					pushfirst!(f.data, [v])
					pushfirst!(f.offset, 0)
					@inbounds for j in 2:l
					    if !iszero(map[j])
					    	map[j] += 1
					    end
					end
				else
					pushfirst!(f.data[1], v)
					f.offset[1] = 0
				end
			else
				id = length(f.data)
				map[i] = id

				if iszero(map[i-1])
					push!(f.data, [v])
					push!(f.offset, l-1)
				else
					push!(f.data[end], v)
				end
			end
		end
	else
		id = map[i]
		insert!(f.data[id], v, i)
		insert!(map, id, i)
		f.offset[id+1:end] .+= 1
	end
end 

function Base.pop!(f::FragmentVector)
	f.map[end] = 0
	r = pop!(f.data[end])

	if isempty(f.data[end])
		pop!(f.data)
		pop!(f.offset)
	end

	return r
end

function Base.deleteat!(f::FragmentVector, i)
	map = f.map
	id = map[i]
	if iszero(id)
		return 
	end

	map[i] = 0

	idx = i - f.offset[id]

	if idx == 1
		f.data[id] = f.data[id][2:end]
	elseif idx == length(f.data[id])
		pop!(f.data[id])
	else
		v = f.data[id]
		vr = v[idx+1:end]
		resize!(v, idx-1)
		insert!(f.data, vr, id+1)
		insert!(f.offset, id, id+1)
	end

	if isempty(f.data[id])
		_deleteat(f.data, id)
		_deleteat(f.offset, id)

		for j in i+1:l
			if !iszero(map[j])
				map[j] -= 1
			end
		end
	end
end

function Base.resize!(f::FragmentVector, n)
	l = length(f)

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



###################################################### HELPERS ######################################################

_length(v::AbstractVector) = length(v)
_length(v::Tuple) = length(v)
_length(n) = 1

function _fuse_block!(dest, src, map, dest_id, offset)
	l1 = length(dest)
	l2 = length(src)
	append!(dest, src)

	@inbounds for i in offset:offset+l2
		map[i] = dest_id
	end
end

function _search_index(offset, i)
	center = length(offset) ÷ 2 + 1
	res = 1
	prev, next = center-1, center+1

	while prev < next
		center = (prev + next)÷2
		offs  = offset[center]
		if offs == i
			return center
		end

		if offs < i
			prev = center+1
		else
			next = center-1
		end

		if prev+2 == center+1 == next
		    return center
		end
	end
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