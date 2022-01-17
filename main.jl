import Base.peek

# open file
function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

# Tokenizer stuff

struct TokenNum
    n :: Int
end

struct TokenId
    str :: String
end

struct TokenPunct
    str :: String
end

struct TokenKw
    str :: String
end

const Token = Union{TokenNum, TokenId, TokenPunct, TokenKw}

function tokenize(text)
    tokens = Token[]
    i = 1
    while i <= length(text)
        # skip whitespaces
        if isspace(text[i]) i += 1; continue end

        if isdigit(text[i]) # start parsing a numeral
            token = string(text[i])
            i += 1
            while i <= length(text) && isdigit(text[i])
                token *= text[i]
                i += 1
            end
            push!(tokens, TokenNum(parse(Int, token)))
            # TODO put other punctuators
        elseif text[i] in "[](){}.;" # see punctuators A.1.7 
            push!(tokens, TokenPunct(string(text[i])))
            i += 1
        elseif isnondigit(text[i])
            token = string(text[i])
            i += 1 # 1st char cannot be a digit, but the others yes
            while i <= length(text) && (isnondigit(text[i]) || isdigit(text[i]))
                token *= text[i]
                i += 1
            end

            # discriminate between identifiers and keywords
            push!(tokens, iskeyword(token) ? TokenKw(token) : TokenId(token))
        else
            error("unhandled character $(text[i])")
        end
    end
    tokens
end

"as defined in the standard, A.1.3"
function isnondigit(c)
    c == '_' || isletter(c)
end

function iskeyword(str)
    # TODO put all A.1.2
    str in ["return"]
end

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
    type :: TokenId
    id :: TokenId
end

struct ASTDecl
    specs :: Vector{TokenKw}
    id :: TokenId # TODO false
end

struct ASTDecltor
    # TODO add the rest 6.7.5
    id :: TokenId
    params :: Vector{ASTParamDecl}
end

struct ASTCmpdStmt
    # TODO for now only compound statements
    items :: Vector{Any} # Union{ASTDecl, ASTStmt} (mutually recursive...)
end

struct ASTReturnStmt
    expr :: TokenNum # TODO for now
end

const ASTJumpStmt = Union{ASTReturnStmt}
const ASTStmt = Union{ASTCmpdStmt, ASTJumpStmt}

struct ASTFunDef
    # TODO add the rest 6.9.1
    type :: TokenId
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
    id = consumeType(r, TokenId)
    params = ASTParamDecl[]
    if(peek(r) == TokenPunct("("))
        next(r) # consume it
        consume(r, TokenPunct(")")) # consume )
    end
    ASTDecltor(id, params)
end

function parseReturnStmt(r)
    consume(r, TokenKw("return"))
    n = consumeType(r, TokenNum)
    ASTReturnStmt(n)
end

function parseCmpdStmt(r)
    consume(r, TokenPunct("{"))

    s = parseReturnStmt(r)
    # TODO change
    consume(r, TokenPunct("}"))
    
    ASTCmpdStmt([s])
end

function parseFunDef(r)
    type = consumeType(r, TokenId)
    decltor = parseDecltor(r)
    stmt = parseCmpdStmt(r)
    ASTFunDef(type, decltor, stmt)
end


# emit assembly
function compileFunDef(def::ASTFunDef, io=stdout)
    println(io, "$(def.decltor.id):")
    # TODO continue from here
end

# unit tests
using Test

begin
    text = "int main()\n{\n    return 42;\n}"
    toks = tokenize(text)

    @testset "tokenizer" begin
        @test toks == [
            TokenId("int"), TokenId("main"), TokenPunct("("), TokenPunct(")"),
            TokenPunct("{"),
            TokenKw("return"), TokenNum(42), TokenPunct(";"),
            TokenPunct("}")
        ]
    end

    r = makereader(toks)
    def = parseFunDef(r)
    print(def)

    compileFunDef(def)
end
