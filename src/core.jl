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

	FragmentVector{T}(::UndefInitializer, n) where T = new{T}(Vector{T}[Vector{T}(undef, n)], fill(1, n), Int[0])

	FragmentVector{T}(args::T...) where T = new{T}(Vector{T}[T[args...]], fill(1, length(args)), Int[0])
	FragmentVector(args::T) where T = FragmentVector{T}(args...)
	FragmentVector{T}(args...) where T = FragmentVector{T}(convert.(T, args))
end