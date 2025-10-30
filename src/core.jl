######################################################################################################################
################################################## CORE ##############################################################
######################################################################################################################

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
	map::Vector{Int}
	offset::Vector{Int}

	## Constructors

	FragmentArray{T}(::UndefInitializer, n) = new{T}(Vector{T}[Vector{T}(undef, n)], fill(1, n), Int[0])

	FragmentVector
end