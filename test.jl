include("main.jl")
using .JCC

using Test

# Step 1 from Ghuloum

T = JCC.Tokens
P = JCC.Parse
A = JCC.AST

"Assemble `test.s`, link it, and make sure it returns 42"
function assemblecheck42()
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
end

function dumpassembly(ast, filename="test.s")
    open(filename, "w") do f
        JCC.withio(f) do
            JCC.compileprelude()
            JCC.compile(ast)
        end
    end
end

# various unit tests for parsing expressions
@testset "expressions" begin
    r(str) = P.makereader(T.tokenize(str))

    # primary expr
    @test P.parsePrimExpr(r("42 f")) == T.Num(42)
    @test P.parsePrimExpr(r("f 42")) == T.Id("f")
    @test_throws ErrorException P.parsePrimExpr(r(";42"))

    # binary op (+)
    @test P.parseAddExpr(r("42 + 4")) == A.BinaryOp(T.Num(42), T.Num(4), T.Punct("+"))

    # unary op
    @test P.parseUniExpr(r("-2")) == A.UnaryOp(T.Num(2), T.Punct("-"))
    @test P.parseExpr(r("-2 * 3")) == A.BinaryOp(
        A.UnaryOp(T.Num(2), T.Punct("-")),
        T.Num(3),
        T.Punct("*")
    )
    @test P.parseExpr(r("-3 * (-11 + 4)")) == A.BinaryOp(
        A.UnaryOp(T.Num(3), T.Punct("-")),
        A.ParenExpr(A.BinaryOp(A.UnaryOp(T.Num(11), T.Punct("-")),
                               T.Num(4),
                               T.Punct("+"))),
        T.Punct("*")
    )

    # assignment
    @test P.parseExpr(r("b = 2")) == A.AssignExpr(T.Id("b"), T.Punct("="), T.Num(2))

    # equality
    @test P.parseExpr(r("b == 2")) == A.BinaryOp(T.Id("b"), T.Num(2), T.Punct("=="))
    @test P.parseExpr(r("x2 != a")) == A.BinaryOp(T.Id("x2"), T.Id("a"), T.Punct("!="))

    function checkbinaryop(op)
        @test P.parseExpr(r("b $op 2")) == A.BinaryOp(T.Id("b"), T.Num(2), T.Punct(op))
        @test P.parseExpr(r("b $op 2 $op 3")) == A.BinaryOp(A.BinaryOp(T.Id("b"), T.Num(2), T.Punct(op)), T.Num(3), T.Punct(op))
    end
    
    checkbinaryop("||") # logical or expr
    checkbinaryop("&&") # logical and expr
    checkbinaryop("|")  # inclusive or expr
    checkbinaryop("^")  # exclusive or expr
    checkbinaryop("&")  # and expr
    # relational exprs
    checkbinaryop("<")
    checkbinaryop(">")
    checkbinaryop("<=")
    checkbinaryop(">=")

    function checkunaryop(op)
        @test P.parseExpr(r("$op b")) == A.UnaryOp(T.Id("b"), T.Punct(op))
    end

    for op in "&*+-~!"
        checkunaryop(string(op))
    end
    checkunaryop("++")
    checkunaryop("--")
end

# various unit tests for parsing declarations
@testset "declarations" begin
    r(str) = P.makereader(T.tokenize(str))
    @test P.parseDecl(r("int x;")) == A.Decl([T.Kw("int")], [A.Decltor(T.Id("x"))])
    @test P.parseDecl(r("int x = 5;")) == A.Decl([T.Kw("int")], [A.DecltorWithInit(A.Decltor(T.Id("x")), T.Num(5))])
end

# various unit tests for parsing statements
@testset "statements" begin
    r(str) = P.makereader(T.tokenize(str))
    @test P.parseStmt(r("return 3;")) == A.ReturnStmt(T.Num(3))
    @test P.parseStmt(r("b = 2;")) == A.ExprStmt(A.AssignExpr(T.Id("b"), T.Punct("="), T.Num(2)))
    @test P.parseStmt(r(";")) == A.ExprStmt()
    @test P.parseStmt(r("if(a){}")) == A.IfStmt(T.Id("a"), A.CmpdStmt([]))
    @test P.parseStmt(r("if(a){}else;")) == A.IfStmt(T.Id("a"), A.CmpdStmt([]), A.ExprStmt())
end

@testset "step 1: integers" begin
    text = """
int main()
{
    return 42;
}
"""
    toks = JCC.tokenize(text)

    @test toks == [
        JCC.Tokens.Kw("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"), JCC.Tokens.Num(42), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]
    
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    dumpassembly(def)
    assemblecheck42()
end


@testset "step 4: binary primitives" begin
    text = """
int main()
{
    return 40 + 2;
}
"""
    toks = JCC.tokenize(text)
    @test toks == [
        JCC.Tokens.Kw("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"),
        JCC.Tokens.Num(40), JCC.Tokens.Punct("+"), JCC.Tokens.Num(2), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]

    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)
    @test def == A.FunDef([T.Kw("int")],
                          A.Decltor(A.DDParams(T.Id("main"),
                                               [], false)),
                          A.CmpdStmt([
                              A.ReturnStmt(A.BinaryOp(T.Num(40),
                                                      T.Num(2),
                                                      T.Punct("+")))
                          ]))

    dumpassembly(def)
    assemblecheck42()
end

# Ghuloum step 3 (I know I did it backward ...): unary primitives
@testset "step 3: unary primitives" begin
    text = """
int main()
{
    return -6 * (-11 + 4);
}
"""
    toks = JCC.tokenize(text)
    @test toks == [
        T.Kw("int"), T.Id("main"), T.Punct("("), T.Punct(")"),
        T.Punct("{"),
        T.Kw("return"),
        T.Punct("-"), T.Num(6), T.Punct("*"),
        T.Punct("("),
        T.Punct("-"), T.Num(11), T.Punct("+"), T.Num(4),
        T.Punct(")"),
        T.Punct(";"),
        T.Punct("}")
    ]

    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    dumpassembly(def)
    assemblecheck42()
end

@testset "step 5: local variables" begin
    text = """
int main()
{
    int a = 40;
    int b;
    b = 4;
    b = 2;
    return a + b;
}
"""
    toks = JCC.tokenize(text)
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    dumpassembly(def)
    assemblecheck42()
end

@testset "step 6: conditionals" begin
    text = """
int main()
{
    int a = 1;
    int b;
    if(a == 0) b = 1;
    else { b = 41; }
    return a + b;
}
"""
    toks = JCC.tokenize(text)
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)
    
    dumpassembly(def)
    assemblecheck42()
end
