using ..Tokens

# Expressions
#=
return 40+2;
=>
ReturnStmt(Expr([AssignmentExpr(CondExpr(LogORExpr(LogANDExpr())))]))

we have a tower of syntax:
expr -> assignmentexpr -> condexpr -> logical-OR-expression -> logical-AND-expression
-> inclusive-OR-expression -> exclusive-OR-expression -> AND-expression
-> equality-expression -> relational-expression -> shift-expression -> additive-expression
-> multiplicative-expression -> cast-expression

This is done to make the priority of operations built into the
grammar. But for clarity we can reorder the hierarchy.

We can follow clang AST:
- binary-op expr expr punct
- unary-op expr punct
- cast expr type
- paren-expr expr
- assignment-expr ...
- primary-expr

 =#

struct BinaryOp{T}
    a :: T
    b :: T
    op :: Tokens.Punct
    BinaryOp(a, b, op) = new{ExprC}(a, b, op)
end

struct UnaryOp{T}
    e :: T
    op :: Tokens.Punct
    UnaryOp(a, op) = new{ExprC}(a, op)
end

struct ParenExpr{T}
    e :: T
    ParenExpr(e) = new{ExprC}(e)
end

const PrimExpr = Union{Tokens.Id, Tokens.Num, ParenExpr}

# TODO put the rest
const ExprC = Union{BinaryOp, UnaryOp, PrimExpr}

Base.:(==)(x::BinaryOp{ExprC}, y::BinaryOp{ExprC}) = x.a == y.a && x.b == y.b && x.op == y.op
Base.:(==)(x::UnaryOp{ExprC}, y::UnaryOp{ExprC}) = x.e == y.e && x.op == y.op
Base.:(==)(x::ParenExpr{ExprC}, y::ParenExpr{ExprC}) = x.e == y.e

struct ParamDecl
    type :: Tokens.Id
    id :: Tokens.Id
end

# TODO for now
const Specifier = Union{Tokens.Id}

# DD stands for direct-declarator
struct DDParen{T}
    decltor :: T
    DDParen(decltor) = new{Decltor}(decltor)
end

struct DDParams{T}
    dd :: T
    params :: Vector{ParamDecl}
    ell :: Bool # true if ends with ...
    DDParams(dd, params, ell) = new{DirectDecltor}(dd, params, ell)
end

const DirectDecltor = Union{Tokens.Id, DDParen, DDParams}

function Base.:(==)(a::DDParams{DirectDecltor}, b::DDParams{DirectDecltor})
    a.dd == b.dd && a.params == b.params && a.ell == b.ell
end

struct Decltor
    ptr :: Union{Nothing} # for now
    direct :: DirectDecltor
end
Decltor(direct::DirectDecltor) = Decltor(nothing, direct)
Base.:(==)(x::Decltor, y::Decltor) = x.ptr == y.ptr && x.direct == y.direct

struct DecltorWithInit
    decltor :: Decltor
    init :: Tokens.Num # TODO for now
end

const InitDecltor = Union{Decltor, DecltorWithInit}

struct Decl
    specs :: Vector{Specifier}
    initds :: Vector{InitDecltor}
end
Base.:(==)(x::Decl, y::Decl) = x.specs == y.specs && x.initds == y.initds

struct CmpdStmt
    # TODO for now only compound statements
    items :: Vector{Any} # Union{Decl, Stmt} (mutually recursive...)
end

Base.:(==)(x::CmpdStmt, y::CmpdStmt) = x.items == y.items

struct ReturnStmt
    expr :: Union{ExprC, Nothing}
end
ReturnStmt() = ReturnStmt(nothing)

const JumpStmt = Union{ReturnStmt}
const Stmt = Union{CmpdStmt, JumpStmt}

struct FunDef
    # TODO add the rest 6.9.1
    specs :: Vector{Specifier}
    decltor :: Decltor
    stmt :: CmpdStmt
end

function Base.:(==)(x::FunDef, y::FunDef)
    x.specs == y.specs && x.decltor == y.decltor && x.stmt == y.stmt
end

# See A.2.4 for this
struct TU # translation unit
    # TODO add decl
    decls :: Vector{FunDef}
end
