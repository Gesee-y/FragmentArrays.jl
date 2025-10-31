######################################################################################################################
################################################## CORE ##############################################################
######################################################################################################################

export FragmentVector

"""
    mutable struct FragmentVector{T}
    	data::Vector{Vector{T}}
	    map::Vector{Int}
	    offsets::::Vector{Int}

Represent a fragmented array. Each time a deletion happens, the array fragment it's data in multiple vectors to
maintain contiguity and eep the globalindex valid
"""
mutable struct FragmentVector{T} <: AbstractVector{T}
	data::Vector{Vector{T}}
	map::Vector{UInt}
	offset::Vector{Int}

	## Constructors

	FragmentVector{T}(::UndefInitializer, n) where T = new{T}(Vector{T}[], fill(zero(UInt), n), Int[])

	FragmentVector{T}(args::T...) where T = new{T}(Vector{T}[T[args...]], fill(one(UInt), length(args)), Int[])
	FragmentVector(args::T...) where T = FragmentVector{T}(args...)
	FragmentVector{T}(args...) where T = FragmentVector{T}(convert.(T, args))
end


struct FragIterRange{T}
    block::Vector{Vector{T}}
    range::Vector{UnitRange{Int}}

    ## Constructors

    FragIterRange{T}() where T = new{T}(Vector{T}[], UnitRange{Int}[])
end

struct FragIter{T}
	block::Vector{T}
	ids::Vector{Vector{Int}}
end