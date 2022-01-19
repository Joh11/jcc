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

struct Decl
    specs :: Vector{Tokens.Kw}
    id :: Tokens.Id # TODO false
end

struct Decltor
    # TODO add the rest 6.7.5
    id :: Tokens.Id
    params :: Vector{ParamDecl}
end

Base.:(==)(x::Decltor, y::Decltor) = x.id == y.id && x.params == y.params

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
    type :: Tokens.Id
    decltor :: Decltor
    stmt :: CmpdStmt
end

function Base.:(==)(x::FunDef, y::FunDef)
    x.type == y.type && x.decltor == y.decltor && x.stmt == y.stmt
end

# See A.2.4 for this
struct TU # translation unit
    # TODO add decl
    decls :: Vector{FunDef}
end
