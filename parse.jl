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

function isempty(r :: Reader)
    r.pos > length(r.tokens)
end

function peek(r :: Reader)
    isempty(r) ? Tokens.EOF : r.tokens[r.pos]
end

function peekis(r::Reader, val)
    peek(r) == val
end

function peekistype(r::Reader, type)
    typeof(peek(r)) <: type
end


function next(r :: Reader)
    r.pos += 1
    (r.pos - 1) <= length(r.tokens) ? r.tokens[r.pos - 1] : Tokens.EOF
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
    if tok != val
        error("unexpected token: expected $val, got $tok")
    else
        next(r)
    end
end

# parse stuff


# declaration stuff

function parseSpecifier(r)
    # TODO add struct union enum and typedef specifier
    if peekistype(r, Tokens.Kw)
        kw = peek(r)
        if kw.str in ["typedef", "extern", "static", "auto", "register"]
            return next(r) # storage class specifier
        elseif kw.str in ["void", "char", "short", "int", "long", "float",
                           "double", "signed", "unsigned", "_Bool", "_Complex"]
            return next(r) # type specifier
        end
    end
    error("unable to parse specifier")
end

function parseManySpecifiers(r)
    # parse specifiers, as many as possible
    specs = []
    c = true
    while c
        try push!(specs, parseSpecifier(r))
        catch err
            if err isa ErrorException
                c = false
            else
                rethrow()
            end
        end
    end
    specs
end

function parseInitDecltor(r)
    d = parseDecltor(r)
    if peekis(r, Tokens.Punct("="))
        next(r)
        # TODO for now
        init = consumeType(r, Tokens.Num)
        AST.DecltorWithInit(d, init)
    else
        d
    end
end

function parseDecl(r)
    specs = parseManySpecifiers(r)

    initdecltors = []
    while peek(r) != Tokens.Punct(";")
        push!(initdecltors, parseInitDecltor(r))
    end
    consume(r, Tokens.Punct(";"))

    AST.Decl(specs, initdecltors)
end

function parseDDParen(r)
    consume(r, Tokens.Punct("("))
    d = parseDecltor(r)
    consume(r, Tokens.Punct(")"))
    AST.DDParen(d)
end

function parseParamList(r)
    params = []
    while !(peek(r) in [Tokens.Punct("..."), Tokens.Punct(")")])
        # TODO do it better
        error("nyi")
    end
    params
end

function parseDD(r)
    if peek(r) == Tokens.Punct("(") # ( declarator )
        parseDDParen(r)
    elseif peek(r) isa Tokens.Id || peek(r) isa Tokens.Kw
        id = next(r)
        n = peek(r)
        if n == Tokens.Punct("(")
            ell = false
            consume(r, Tokens.Punct("("))
            params = parseParamList(r)
            if peek(r) == Tokens.Punct("...")
                consume(r, Tokens.Punct("..."))
                ell = true
            end
            consume(r, Tokens.Punct(")"))
            AST.DDParams(id, params, ell)
        else
            id
        end
    else
        error("nyi dd, token $(peek(r))")
    end
end

function parseDecltor(r)
    # TODO parse pointer things
    direct = parseDD(r)
    AST.Decltor(direct)
end

function parseReturnStmt(r)
    consume(r, Tokens.Kw("return"))
    e = nothing
    if peek(r) != Tokens.Punct(";")
        e = parseExpr(r)
    end
    consume(r, Tokens.Punct(";"))
    AST.ReturnStmt(e)
end

function parseStmt(r)
    # TODO all other statements
    @info "parse stmt $(peek(r))"
    if peekis(r, Tokens.Punct("{"))
        @info "parse cmpd stmt"
        parseCmpdStmt(r)
    elseif peekis(r, Tokens.Kw("if"))
        @info "parse if stmt"
        parseIfStmt(r)
    elseif peekis(r, Tokens.Kw("return"))
        @info "parse return stmt"
        parseReturnStmt(r)
    else
        @info "parse expr stmt"
        parseExprStmt(r)
    end
end

function parseIfStmt(r)
    consume(r, Tokens.Kw("if"))
    consume(r, Tokens.Punct("("))
    cond = parseExpr(r)
    consume(r, Tokens.Punct(")"))
    then = parseStmt(r)
    els = nothing
    if peekis(r, Token.Kw("else"))
        next(r)
        els = parseStmt(r)
    end
    
    AST.IfStmt(cond, then, els)
end

function parseExprStmt(r)
    e = parseExpr(r)
    consume(r, Tokens.Punct(";"))
    AST.ExprStmt(e)
end

function parseCmpdStmt(r)
    consume(r, Tokens.Punct("{"))

    items = []
    while peek(r) != Tokens.Punct("}")
        # TODO try parsing a declaration or a statement
        
        # I flipped the parsing of stmt and decl, because it now
        # parses correctly "b=5;" as an expression statement. Let's
        # see if this is correct...
        pos = r.pos
        try 
            push!(items, parseStmt(r))            
        catch err
            r.pos = pos # back to where it was
            push!(items, parseDecl(r))
        end
    end
    consume(r, Tokens.Punct("}"))
    
    AST.CmpdStmt(items)
end

function parseFunDef(r)
    specs = parseManySpecifiers(r)
    decltor = parseDecltor(r)
    # TODO declaration list, but this is old so low priority
    stmt = parseCmpdStmt(r)

    AST.FunDef(specs, decltor, stmt)
end

function parseParenExpr(r)
    consume(r, Tokens.Punct("("))
    e = parseExpr(r)
    consume(r, Tokens.Punct(")"))
    AST.ParenExpr(e)
end

function parsePrimExpr(r)
    t = peek(r)
    if t isa Tokens.Punct
        parseParenExpr(r)
    elseif t isa Tokens.Num || t isa Tokens.Id
        next(r)
    end
end

function parseExpr(r)
    # I think the idea would be to try to parse the top of the AST
    # hierarchy (that is an assignment expression)

    # since for now assignments expression are not implemented, it
    # would be the second, that is conditional-expr

    # these are not implemented yet either, and so on, so start with
    # additive-expression

    # TODO implement the full tower
    parseAssignExpr(r)
end

function parseAssignExpr(r)
    # TODO do it properly with right recursive tree
    # save it to backtrack
    pos = r.pos
    
    a = parseUniExpr(r)
    if peek(r) in map(Tokens.Punct, ["=", "*=", "/=", "%=",
                                     "+=", "-=", "<<=", ">>=",
                                     "&=", "^=", "|="])
        op = next(r)
        b = parseAddExpr(r)
        AST.AssignExpr(a, op, b)
    else
        r.pos = pos # come back
        parseCondExpr(r)
    end
end

function parseCondExpr(r)
    # TODO
    parseEqExpr(r)
end

function leftrectree!(operands, ops)
    # used by all the binary ops
    @assert length(operands) == length(ops) + 1
    while length(ops) > 0
        operands[1] = AST.BinaryOp(operands[1], operands[2], ops[1])
        deleteat!(operands, 2)
        popfirst!(ops)
    end
    operands[1]
end

function parseEqExpr(r)
    # TODO skip rel expr for now
    operands = Any[parseAddExpr(r)]
    ops = []
    while peek(r) in [Tokens.Punct("=="), Tokens.Punct("!=")]
        push!(ops, next(r))
        push!(operands, parseAddExpr(r))
    end

    # construct the left recursive tree now
    leftrectree!(operands, ops)
end

function parseAddExpr(r)
    operands = Any[parseMultExpr(r)]
    ops = []
    while peek(r) in [Tokens.Punct("+"), Tokens.Punct("-")]
        push!(ops, next(r))
        push!(operands, parseMultExpr(r))
    end

    # construct the left recursive tree now
    leftrectree!(operands, ops)
end

function parseMultExpr(r)
    # TODO skip cast expr for now
    operands = Any[parseUniExpr(r)]
    ops = []
    mulops = [Tokens.Punct(string(x)) for x in "*/%"]
    while peek(r) in mulops
        push!(ops, next(r))
        push!(operands, parseUniExpr(r))
    end

    # construct the left recursive tree now
    leftrectree!(operands, ops)    
end

# TODO skip cast expr for now
parseCastExpr(r) = parseUniExpr(r)

# TODO implement postfix expr
parsePFExpr(r) = parsePrimExpr(r)

function parseUniExpr(r)
    # TODO parse the rest (6.5.3)
    # that is postfix, ++, --, sizeof exp, sizeof(typename)

    uniops = [Tokens.Punct(string(x)) for x in "&*+-~!"]
    if peek(r) in uniops
        op = next(r)
        e = parseCastExpr(r)
        AST.UnaryOp(e, op)
    else
        parsePFExpr(r)
    end
end
