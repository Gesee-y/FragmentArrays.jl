######################################################################################################################
################################################## CORE ##############################################################
######################################################################################################################

export FragmentVector

export AbstractFragmentVector, AbstractFragmentLayout, AbstractArrayLayout
export DenseVectorLayout

abstract type AbstractFragmentVector{T, L} <: AbstractVector{T} end
abstract type AbstractFragmentLayout end
abstract type AbstractArrayLayout{T} <: AbstractFragmentLayout end

struct VectorLayout{T} <: AbstractArrayLayout{T}
    data::Vector{T}

    ## Constructors

    VectorLayout{T}(::UndefInitializer, n) where T = new{T}(Vector{T}(undef, n))
    VectorLayout(args::T...) where T = new{T}(T[args...])
    VectorLayout{T}(args...) where T = new{T}(T[args...])
end

"""
    mutable struct FragmentVector{T}
    	data::Vector{Vector{T}}
	    map::Vector{Int}
	    offsets::Vector{Int}

Represent a fragmented array. Each time a deletion happens, the array fragment it's data in multiple vectors to
maintain contiguity and eep the globalindex valid
"""
mutable struct FragmentVector{T, L} <: AbstractFragmentVector{T, L}
	data::Vector{L}
	map::Vector{UInt}
	offset::Vector{Int}

	## Constructors

	FragmentVector{T, C}(::UndefInitializer, n) where {T, C} = new{T, C{T}}(C{T}[], fill(zero(UInt), n), Int[])

	FragmentVector{T, C}(args...) where {T, C} = new{T, C{T}}(C{T}[initialize_layout(C{T}, args...)], fill(one(UInt), length(args)), Int[])
	FragmentVector(args::T...) where T = FragmentVector{T, VectorLayout}(args...)
end


struct FragIterRange{T}
    block::Vector{T}
    range::Vector{UnitRange{Int}}

    ## Constructors

    FragIterRange{T}() where T = new{T}(T[], UnitRange{Int}[])
end

struct FragIter{T}
	block::Vector{T}
	ids::Vector{Vector{Int}}

	## Constructors

	FragIter{T}() where T = new{T}(T[], Vector{Int}[])
end

function Base.show(io::IO, f::FragmentVector)
    print(io, "[")
    map = f.map
    n = length(map)
    for i in 1:n
        mask = map[i]
        if iszero(mask)
            print(io, ".")
        else
            blockid = mask >> 32
            offset  = mask & ((1 << 32) - 1)
            val = f.data[blockid][i - offset]
            print(io, val)
        end
        if i < n
            print(io, ", ")
        end
    end
    print(io, "]")
end
Base.show(f::FragmentVector) = show(stdout, f)

################################################################################ HELPERS ####################################################################################

_initialize(::Vector{T}, args...) where T = T[args...] 