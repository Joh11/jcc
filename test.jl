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

@testset "step 1: integers" begin
    text = """
int main()
{
    return 42;
}
"""
    toks = JCC.tokenize(text)

    @test toks == [
        JCC.Tokens.Id("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"), JCC.Tokens.Num(42), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]
    
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    dumpassembly(def)
    assemblecheck42()
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
end

# various unit tests for parsing declarations
@testset "declarations" begin
    r(str) = P.makereader(T.tokenize(str))
    @test P.parseDecl(r("int x;")) == A.Decl([T.Id("int")], [A.Decltor(T.Id("x"))])
    @test P.parseDecl(r("int x = 5;")) == A.Decl([T.Id("int")], [A.DecltorWithInit(A.Decltor(T.Id("x")), T.Num(5))])
end

# various unit tests for parsing statements
@testset "statements" begin
    r(str) = P.makereader(T.tokenize(str))
    @test P.parseStmt(r("return 3;")) == A.ReturnStmt(T.Num(3))
    @test P.parseStmt(r("b = 2;")) == A.ExprStmt(A.AssignExpr(T.Id("b"), T.Punct("="), T.Num(2)))
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
        JCC.Tokens.Id("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"),
        JCC.Tokens.Num(40), JCC.Tokens.Punct("+"), JCC.Tokens.Num(2), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]

    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)
    @test def == A.FunDef([T.Id("int")],
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
        T.Id("int"), T.Id("main"), T.Punct("("), T.Punct(")"),
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

# Ghuloum step 5: local variables
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
