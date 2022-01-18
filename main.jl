module JCC

import Base.peek

# export tokenize
# # export TokensId, Tokens.Punct, Tokens.Kw, Tokens.Num
# export makereader
# export parseFunDef
# export compile, withio, compileprelude

# open file
function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

# Tokenizer stuff

module Tokens
include("token.jl")
end

using .Tokens

# Parser stuff

mutable struct Reader
    pos :: Int
    tokens :: Vector{Token}
end

function makereader(tokens)
    @assert length(tokens) > 0
    Reader(1, tokens)
end

function peek(r :: Reader)
    r.tokens[r.pos]
end

function next(r :: Reader)
    r.pos += 1
    r.tokens[r.pos - 1]
end

function consumeType(r::Reader, type)
    tok = peek(r)
    if !(typeof(tok) <: type)
        error("wrong type for token: expected $type, got $(tok)")
    else
        next(r)
    end
end

function consume(r::Reader, val)
    tok = peek(r)
    if typeof(tok) == val
        error("unexpected token: expeced $val, got $tok")
    else
        next(r)
    end
end

struct ASTParamDecl
    type :: Tokens.Id
    id :: Tokens.Id
end

struct ASTDecl
    specs :: Vector{Tokens.Kw}
    id :: Tokens.Id # TODO false
end

struct ASTDecltor
    # TODO add the rest 6.7.5
    id :: Tokens.Id
    params :: Vector{ASTParamDecl}
end

struct ASTCmpdStmt
    # TODO for now only compound statements
    items :: Vector{Any} # Union{ASTDecl, ASTStmt} (mutually recursive...)
end

struct ASTReturnStmt
    expr :: Tokens.Num # TODO for now
end

const ASTJumpStmt = Union{ASTReturnStmt}
const ASTStmt = Union{ASTCmpdStmt, ASTJumpStmt}

struct ASTFunDef
    # TODO add the rest 6.9.1
    type :: Tokens.Id
    decltor :: ASTDecltor
    stmt :: ASTCmpdStmt
end

# See A.2.4 for this
struct ASTTU # translation unit
    # TODO add decl
    decls :: Vector{ASTFunDef}
end

# parse stuff
function parseDecltor(r)
    id = consumeType(r, Tokens.Id)
    params = ASTParamDecl[]
    if(peek(r) == Tokens.Punct("("))
        next(r) # consume it
        consume(r, Tokens.Punct(")")) # consume )
    end
    ASTDecltor(id, params)
end

function parseReturnStmt(r)
    consume(r, Tokens.Kw("return"))
    n = consumeType(r, Tokens.Num)
    ASTReturnStmt(n)
end

function parseCmpdStmt(r)
    consume(r, Tokens.Punct("{"))

    s = parseReturnStmt(r)
    # TODO change
    consume(r, Tokens.Punct("}"))
    
    ASTCmpdStmt([s])
end

function parseFunDef(r)
    type = consumeType(r, Tokens.Id)
    decltor = parseDecltor(r)
    stmt = parseCmpdStmt(r)
    ASTFunDef(type, decltor, stmt)
end


# emit assembly

# all functions for code generation will have the form `compile(t)`,
# and use a global state to control the output stream

global io = stdout

function withio(f, s)
    global io
    oldio = io
    io = s
    f()
    io = oldio
    nothing
end

function compileprelude()
    println(io, ".text")
    println(io, ".globl _start")
    println(io, "_start:")
    println(io, "call main")
    println(io, "mov %rax, %rdi")
    println(io, "mov \$60, %rax")
    println(io, "syscall")
    println(io, "")
end

function compile(def::ASTFunDef)
    # println(io, "# function $(def.decltor.id.str)")
    println(io, "$(def.decltor.id.str):")
    println(io, "push %rbp")
    println(io, "movq %rsp, %rbp")
    
    # TODO compile body
    # Union{ASTDecl, ASTStmt}
    for stmt in def.stmt.items
        compile(stmt)
    end
end

function compile(stmt::ASTReturnStmt)
    # assume expressions evaluate themselves to %eax
    compile(stmt.expr)
    println(io, "popq %rbp")
    println(io, "ret")
end

function compile(n::Tokens.Num)
    # TODO make sure this integer fits into 64 bits
    println(io, "movl \$$(n.n), %eax")
end

end # module JCC
