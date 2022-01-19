module JCC

# open file
function readfile(path="test.c")
    open(path) do f
        join(readlines(f), "\n")
    end
end

module Tokens include("token.jl") end

# Contains only the definitions of the grammar, not the parsing
# function themselves
module AST include("ast.jl") end
module Parse include("parse.jl") end
module Compile include("compile.jl") end

using .Tokens
using .AST
using .Parse
using .Compile

function rpn(d::AST.Decl)
    ret = rpn(d.specs)
    ret *= rpn(d.initds)
    ret *= "decl "
end

function rpn(d::AST.Decltor)
    ret = ""# rpn(d.ptr) TODO
    ret *= rpn(d.direct)
    ret *= "decltor "
end

function rpn(dd::AST.DDParams)
    ret = rpn(dd.dd)
    ret *= rpn(dd.params)
    if dd.ell ret *= "... " end
    ret * "direct-declarator-params "
end

function rpn(d::AST.DecltorWithInit)
    ret = rpn(d.decltor)
    ret *= rpn(d.init)
    ret * "declarator-w/-init "
end

function rpn(s::AST.CmpdStmt)
    ret = rpn(s.items)
    ret * "{} "
end

function rpn(f::AST.FunDef)
    ret = rpn(f.specs)
    ret *= rpn(f.decltor)
    ret *= rpn(f.stmt)
    ret * "fundef "
end

function rpn(s::AST.ReturnStmt)
    ret = rpn(s.expr)
    ret * "return "
end

function rpn(s::AST.ExprStmt)
    ret = rpn(s.expr)
    ret * "; "
end

function rpn(s::AST.AssignExpr)
    ret = rpn(s.a)
    ret *= rpn(s.op)
    ret *= rpn(s.b)
    ret * "assign "
end

function rpn(s::AST.BinaryOp{AST.ExprC})
    ret = rpn(s.a)
    ret *= rpn(s.b)
    ret *= rpn(s.op)
    ret * "binary-op "
end

rpn(kw::Tokens.Kw) = "#$(kw.str) "
rpn(id::Tokens.Id) = "<$(id.str)> "
rpn(n::Tokens.Num) = "\$$(n.n) "
rpn(p::Tokens.Punct) = ".$(p.str). "

function rpn(xs::Vector{T} where T)
    ret = ""
    for x in xs
        ret *= rpn(x)
    end
    ret * "[] "
end

end # module JCC
