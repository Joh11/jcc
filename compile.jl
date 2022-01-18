using ..Tokens
using ..AST

export withio, compileprelude, compile

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

function compile(def::AST.FunDef)
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

function compile(stmt::AST.ReturnStmt)
    # assume expressions evaluate themselves to %eax
    compile(stmt.expr)
    println(io, "popq %rbp")
    println(io, "ret")
end

function compile(n::Tokens.Num)
    # TODO make sure this integer fits into 64 bits
    println(io, "movl \$$(n.n), %eax")
end
