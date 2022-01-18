using ..Tokens
using ..AST

export makereader, parseFunDef

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

# parse stuff
function parseDecltor(r)
    id = consumeType(r, Tokens.Id)
    params = AST.ParamDecl[]
    if(peek(r) == Tokens.Punct("("))
        next(r) # consume it
        consume(r, Tokens.Punct(")")) # consume )
    end
    AST.Decltor(id, params)
end

function parseReturnStmt(r)
    consume(r, Tokens.Kw("return"))
    n = consumeType(r, Tokens.Num)
    AST.ReturnStmt(n)
end

function parseCmpdStmt(r)
    consume(r, Tokens.Punct("{"))

    s = parseReturnStmt(r)
    # TODO change
    consume(r, Tokens.Punct("}"))
    
    AST.CmpdStmt([s])
end

function parseFunDef(r)
    type = consumeType(r, Tokens.Id)
    decltor = parseDecltor(r)
    stmt = parseCmpdStmt(r)
    AST.FunDef(type, decltor, stmt)
end
