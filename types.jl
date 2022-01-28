using ..Tokens
using ..AST

struct BasicType
    name :: String
end

const UnqualifiedType = Union{BasicType}

struct Qualified{T}
    unqual     :: T
    isconst    :: Bool
    isvolatile :: Bool
    isrestrict :: Bool
end

struct ArrayType{T}
    elem :: Qualified{T}
    size :: Int
end

struct PointerType{T}
    ref :: Qualified{T}
end

Qualified(unqual) = Qualified(unqual, false, false, false)
ConstQualified(unqual) = Qualified(unqual, true, false, false)

# examples:

# int
# @info Qualified(BasicType("int"))

# # int[3]
# @info Qualified(ArrayType(Qualified(BasicType("int")), 3))

# # int*
# @info Qualified(PointerType(Qualified(BasicType("int"))))



# functions

"""Return the type of the given declaration. If it declares multiple
identifiers, throw an error for now. """
function gettype(decl :: AST.Decl)
    # get the specifier on one side
    specs = decl.specs
    # get the *, [] and more on the other
    # TODO

    # parse the specifiers

    # TODO for now *, () and [] are not implemented, so we only have
    # basic types.

    # order does not matter
    isconst = any(x -> x == Tokens.Kw("const"), specs)
    isvolatile = any(x -> x == Tokens.Kw("volatile"), specs)
    isrestrict = any(x -> x == Tokens.Kw("restrict"), specs)

    # remove the type qualifiers and the before parsing
    quals = ["const", "volatile", "restrict"]
    storageclass = ["typedef", "extern", "static", "auto", "register"]

    specsnoqual = filter(x -> ! (x in map(Tokens.Kw, [quals; storageclass])),
                         specs)
    Qualified(basictypefromspecs(specsnoqual), isconst, isvolatile, isrestrict)
end

function basictypefromspecs(s)
    @assert all(x -> x isa Tokens.Kw, s)
    s = sort(map(x -> x.str, s))
    
    # TODO implement the whole list from 6.7.2 2.

    if s == ["void"] BasicType("void")
    elseif s == ["char"] BasicType("char")
        # ...
    elseif s in [["int"], ["signed"], ["int", "signed"]] BasicType("int")
        # ...
    else
        error("not a basic type: $s")
    end
end
