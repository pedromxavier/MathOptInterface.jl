# Copyright (c) 2017: Miles Lubin and contributors
# Copyright (c) 2017: Google Inc.
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

"""
    CountGreaterThanToMILPBridge{T,F} <: Bridges.Constraint.AbstractBridge

`CountGreaterThanToMILPBridge` implements the following reformulation:

  * ``(c, y, x) \\in CountGreaterThan()`` into a mixed-integer linear program.

## Source node

`CountGreaterThanToMILPBridge` supports:

  * `F` in [`MOI.CountGreaterThan`](@ref)

## Target nodes

`CountGreaterThanToMILPBridge` creates:

  * [`MOI.VariableIndex`](@ref) in [`MOI.ZeroOne`](@ref)
  * [`MOI.ScalarAffineFunction{T}`](@ref) in [`MOI.EqualTo{T}`](@ref)
  * [`MOI.ScalarAffineFunction{T}`](@ref) in [`MOI.GreaterThan{T}`](@ref)
"""
struct CountGreaterThanToMILPBridge{
    T,
    F<:Union{MOI.VectorOfVariables,MOI.VectorAffineFunction{T}},
} <: AbstractBridge
    f::F
    s::MOI.CountGreaterThan
    variables::Vector{MOI.VariableIndex}
    greater_than::Vector{
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.GreaterThan{T}},
    }
    equal_to::Vector{
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}},
    }
end

const CountGreaterThanToMILP{T,OT<:MOI.ModelLike} =
    SingleBridgeOptimizer{CountGreaterThanToMILPBridge{T},OT}

function bridge_constraint(
    ::Type{CountGreaterThanToMILPBridge{T,F}},
    model::MOI.ModelLike,
    f::F,
    s::MOI.CountGreaterThan,
) where {T,F}
    return CountGreaterThanToMILPBridge{T,F}(
        f,
        s,
        MOI.VariableIndex[],
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.GreaterThan{T}}[],
        MOI.ConstraintIndex{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}}[],
    )
end

function MOI.supports_constraint(
    ::Type{<:CountGreaterThanToMILPBridge{T}},
    ::Type{F},
    ::Type{MOI.CountGreaterThan},
) where {T,F<:Union{MOI.VectorOfVariables,MOI.VectorAffineFunction{T}}}
    return true
end

function MOI.Bridges.added_constrained_variable_types(
    ::Type{<:CountGreaterThanToMILPBridge},
)
    return Tuple{Type}[(MOI.ZeroOne,)]
end

function MOI.Bridges.added_constraint_types(
    ::Type{<:CountGreaterThanToMILPBridge{T}},
) where {T}
    return Tuple{Type,Type}[
        (MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}),
        (MOI.ScalarAffineFunction{T}, MOI.GreaterThan{T}),
    ]
end

function concrete_bridge_type(
    ::Type{<:CountGreaterThanToMILPBridge{T}},
    ::Type{F},
    ::Type{MOI.CountGreaterThan},
) where {T,F<:Union{MOI.VectorOfVariables,MOI.VectorAffineFunction{T}}}
    return CountGreaterThanToMILPBridge{T,F}
end

function MOI.get(
    ::MOI.ModelLike,
    ::MOI.ConstraintFunction,
    bridge::CountGreaterThanToMILPBridge,
)
    return bridge.f
end

function MOI.get(
    ::MOI.ModelLike,
    ::MOI.ConstraintSet,
    bridge::CountGreaterThanToMILPBridge,
)
    return bridge.s
end

function MOI.delete(model::MOI.ModelLike, bridge::CountGreaterThanToMILPBridge)
    MOI.delete.(model, bridge.greater_than)
    empty!(bridge.greater_than)
    MOI.delete.(model, bridge.equal_to)
    empty!(bridge.equal_to)
    MOI.delete.(model, bridge.variables)
    empty!(bridge.variables)
    return
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge,
    ::MOI.NumberOfVariables,
)::Int64
    return length(bridge.variables)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge,
    ::MOI.ListOfVariableIndices,
)
    return copy(bridge.variables)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge,
    ::MOI.NumberOfConstraints{MOI.VariableIndex,MOI.ZeroOne},
)::Int64
    return length(bridge.variables)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge,
    ::MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.ZeroOne},
)
    return [
        MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}.(z.value) for
        z in bridge.variables
    ]
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge{T},
    ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}},
)::Int64 where {T}
    return length(bridge.equal_to)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge{T},
    ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T},MOI.EqualTo{T}},
) where {T}
    return copy(bridge.equal_to)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge{T},
    ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T},MOI.GreaterThan{T}},
)::Int64 where {T}
    return length(bridge.greater_than)
end

function MOI.get(
    bridge::CountGreaterThanToMILPBridge{T},
    ::MOI.ListOfConstraintIndices{
        MOI.ScalarAffineFunction{T},
        MOI.GreaterThan{T},
    },
) where {T}
    return copy(bridge.greater_than)
end

MOI.Bridges.needs_final_touch(::CountGreaterThanToMILPBridge) = true

# We use the bridge as the first argument to avoid type piracy of other methods.
function _get_bounds(
    bridge::CountGreaterThanToMILPBridge{T},
    model::MOI.ModelLike,
    bounds::Dict{MOI.VariableIndex,NTuple{2,T}},
    f::MOI.ScalarAffineFunction{T},
) where {T}
    lb = ub = f.constant
    for term in f.terms
        ret = _get_bounds(bridge, model, bounds, term.variable)
        if ret === nothing
            return nothing
        end
        lb += term.coefficient * ret[1]
        ub += term.coefficient * ret[2]
    end
    return lb, ub
end

# We use the bridge as the first argument to avoid type piracy of other methods.
function _get_bounds(
    ::CountGreaterThanToMILPBridge{T},
    model::MOI.ModelLike,
    bounds::Dict{MOI.VariableIndex,NTuple{2,T}},
    x::MOI.VariableIndex,
) where {T}
    if haskey(bounds, x)
        return bounds[x]
    end
    ret = MOI.Utilities.get_bounds(model, T, x)
    if ret == (typemin(T), typemax(T))
        return nothing
    end
    bounds[x] = ret
    return ret
end

function _add_unit_expansion(
    bridge::CountGreaterThanToMILPBridge{T,F},
    model::MOI.ModelLike,
    S,
    bounds,
    x,
) where {T,F}
    ret = _get_bounds(bridge, model, bounds, x)
    if ret === nothing
        error(
            "Unable to use $(typeof(bridge)) because an element in the " *
            "function has a non-finite domain: $x",
        )
    end
    unit_f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{T}[], zero(T))
    convex_f = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{T}[], zero(T))
    for xi in ret[1]::T:ret[2]::T
        new_var, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())
        push!(bridge.variables, new_var)
        if !haskey(S, xi)
            S[xi] = Tuple{Float64,MOI.VariableIndex}[]
        end
        push!(S[xi], new_var)
        push!(unit_f.terms, MOI.ScalarAffineTerm(T(-xi), new_var))
        push!(convex_f.terms, MOI.ScalarAffineTerm(one(T), new_var))
    end
    push!(
        bridge.equal_to,
        MOI.Utilities.normalize_and_add_constraint(
            model,
            MOI.Utilities.operate(+, T, x, unit_f),
            MOI.EqualTo(zero(T));
            allow_modify_function = true,
        ),
    )
    push!(
        bridge.equal_to,
        MOI.add_constraint(model, convex_f, MOI.EqualTo(one(T))),
    )
    return
end

function MOI.Bridges.final_touch(
    bridge::CountGreaterThanToMILPBridge{T,F},
    model::MOI.ModelLike,
) where {T,F}
    # Clear any existing reformulations!
    MOI.delete(model, bridge)
    Sx = Dict{T,Vector{MOI.VariableIndex}}()
    Sy = Dict{T,Vector{MOI.VariableIndex}}()
    scalars = collect(MOI.Utilities.eachscalar(bridge.f))
    bounds = Dict{MOI.VariableIndex,NTuple{2,T}}()
    _add_unit_expansion(bridge, model, Sy, bounds, scalars[2])
    for i in 3:length(scalars)
        _add_unit_expansion(bridge, model, Sx, bounds, scalars[i])
    end
    # We use a sort so that the model order is deterministic.
    for s in sort!(collect(keys(Sy)))
        if haskey(Sx, s)
            M = length(Sx[s])
            terms = [MOI.ScalarAffineTerm(one(T), x) for x in Sx[s]]
            push!(terms, MOI.ScalarAffineTerm(T(M), first(Sy[s])))
            f = MOI.Utilities.operate(
                -,
                T,
                scalars[1],
                MOI.ScalarAffineFunction(terms, zero(T)),
            )
            ci = MOI.Utilities.normalize_and_add_constraint(
                model,
                f,
                MOI.GreaterThan(T(1 - M));
                allow_modify_function = true,
            )
            push!(bridge.greater_than, ci)
        end
    end
    return
end
