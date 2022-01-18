using ..Tokens

struct ParamDecl
    type :: Tokens.Id
    id :: Tokens.Id
end

struct Decl
    specs :: Vector{Tokens.Kw}
    id :: Tokens.Id # TODO false
end

struct Decltor
    # TODO add the rest 6.7.5
    id :: Tokens.Id
    params :: Vector{ParamDecl}
end

struct CmpdStmt
    # TODO for now only compound statements
    items :: Vector{Any} # Union{Decl, Stmt} (mutually recursive...)
end

struct ReturnStmt
    expr :: Tokens.Num # TODO for now
end

const JumpStmt = Union{ReturnStmt}
const Stmt = Union{CmpdStmt, JumpStmt}

struct FunDef
    # TODO add the rest 6.9.1
    type :: Tokens.Id
    decltor :: Decltor
    stmt :: CmpdStmt
end

# See A.2.4 for this
struct TU # translation unit
    # TODO add decl
    decls :: Vector{FunDef}
end
