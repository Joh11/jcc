using ..Tokens
using ..AST

export withio, compileprelude, compile

# emit assembly

# all functions for code generation will have the form `compile(t)`,
# and use a global state to control the output stream

mutable struct Context
    io :: IO
    topstack :: Int
end

global ctx = Context(stdout, 0)

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
    emit("$(def.decltor.id.str):")
    emit("push %rbp")
    emit("movq %rsp, %rbp")

    # compile body
    for stmt in def.stmt.items
        compile(stmt)
    end
end

function compile(stmt::AST.ReturnStmt)
    # assume expressions evaluate themselves to %eax
    compile(stmt.expr)
    emit("popq %rbp")
    emit("ret")
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


function compile(n::Tokens.Num)
    # TODO make sure this integer fits into 64 bits
    emit("movl \$$(n.n), %eax")
end
