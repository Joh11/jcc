using ..Tokens
using ..AST

export withio, compileprelude, compile

# emit assembly

# all functions for code generation will have the form `compile(t)`,
# and use a global state to control the output stream

mutable struct Env
    vars :: Dict{String, Int}
    topstack :: Int
end

mutable struct Context
    io :: IO
    topstack :: Int
    envs :: Vector{Env}
end

global ctx = Context(stdout, 0, [])

function withio(f, s)
    global ctx
    oldio = ctx.io
    ctx.io = s
    f()
    ctx.io = oldio;
end

"Emit the given string to the context IO"
function emit(str)
    # put a tab for any nonlabel instruction
    tab = isempty(str) || str[end] == ':' ? "" : "\t"
    println(ctx.io, tab * str)
end

"""Allocate `nbytes` on the stack. Actually decrease `ctx.topstack` by
this given amount"""
function stackalloc(nbytes)
    ctx.topstack -= nbytes
end

"Opposite of stackalloc"
function stackfree(nbytes)
    ctx.topstack += nbytes
end

function pushenv(vars::Dict{String, Int}=Dict{String, Int}())
    push!(ctx.envs, Env(vars, ctx.topstack))
end

function popenv()
    ctx.topstack = ctx.envs[end].topstack
    pop!(ctx.envs)
end

function envget(id::String)
    for k = length(ctx.envs):-1:1
        if id in keys(ctx.envs[k].vars)
            return ctx.envs[k].vars[id]
        end
    end
    error("could not find the variable $id")
end

envget(id::Tokens.Id) = envget(id.str)

function compileprelude()
    emit(".text")
    emit(".globl _start")
    emit("_start:")
    emit("call main")
    emit("mov %rax, %rdi")
    emit("mov \$60, %rax")
    emit("syscall")
    emit("")
end

function compile(def::AST.FunDef)
    emit("$(def.decltor.direct.dd.str):")
    emit("push %rbp")
    emit("movq %rsp, %rbp")

    # compile body
    compile(def.stmt)
end

function compile(stmt::AST.CmpdStmt)
    # split between declarations and statements
    decls = filter(x -> x isa AST.Decl, stmt.items)
    stmts = filter(x -> x isa AST.Stmt, stmt.items)

    pushenv()
    for decl in decls
        # check they are all int for now
        @assert decl.specs == [Tokens.Kw("int")]
        for initd in decl.initds
            dd = initd isa AST.Decltor ? initd.direct : initd.decltor.direct
            @assert dd isa Tokens.Id
            
            stackalloc(4)
            ctx.envs[end].vars[dd.str] = ctx.topstack
        end
    end

    # initialize the variables if required
    for decl in decls
        # check they are all int for now
        @assert decl.specs == [Tokens.Kw("int")]
        for initd in decl.initds
            if initd isa AST.DecltorWithInit
                name = initd.decltor.direct.str
                init = initd.init

                # TODO only if int
                compile(init)
                emit("movl %eax, $(envget(name))(%rsp)")
            end
        end
    end
    
    # compile statements
    for stmt in stmts
        compile(stmt)
    end

    popenv()
end

function compile(stmt::AST.ExprStmt)
    compile(stmt.expr)
end

function compile(stmt::AST.ReturnStmt)
    # assume expressions evaluate themselves to %eax
    compile(stmt.expr)
    emit("popq %rbp")
    emit("ret")
end

function compile(e::AST.AssignExpr)
    # TODO deal with non simple lvalue
    compile(e.b)
    # TODO deal with more operators later
    @assert e.op == Tokens.Punct("=")
    # TODO make sure a is real variable
    @assert e.a isa Tokens.Id
    offset = envget(e.a)
    # TODO only works for int
    emit("movl %eax, $(offset)(%rsp)")
end

function compile(e::AST.BinaryOp{AST.ExprC})
    op = e.op
    # compile the operands, and assume they are now pushed onto the
    # stack
    compile(e.a)
    # save the value of %eax onto the stack
    stackalloc(4) # bc 32 bits int
    emit("movl %eax, $(ctx.topstack)(%rsp)")
    compile(e.b)
    if op == Tokens.Punct("+")
        emit("addl $(ctx.topstack)(%rsp), %eax")
    elseif op == Tokens.Punct("*")
        emit("imull $(ctx.topstack)(%rsp), %eax")
    else
        error("nyi: binary op $(e.op)")
    end
    stackfree(4) # bc 32 bits int
end

function compile(e::AST.UnaryOp{AST.ExprC})
    compile(e.e)
    # TODO beware of the size of the type
    if e.op == Tokens.Punct("-")
        emit("negl %eax")
    else
        error("nyi: unary op $(e.op)")
    end
end

function compile(e::AST.ParenExpr{AST.ExprC})
    compile(e.e)
end

function compile(n::Tokens.Id)
    # TODO only for int
    emit("movl $(envget(n))(%rsp), %eax")
end

function compile(n::Tokens.Num)
    # TODO make sure this integer fits into 64 bits
    emit("movl \$$(n.n), %eax")
end
