include("main.jl")
using .JCC

using Test

# Step 1 from Ghuloum

T = JCC.Tokens
P = JCC.Parse
A = JCC.AST

# various unit tests for parsing declarations
@testset "declarations" begin
    r(str) = P.makereader(T.tokenize(str))
    @test P.parseDecl(r("int x;")) == A.Decl([T.Id("int")], [A.Decltor(T.Id("x"))])
end


text = """
    int main()
    {
        return 42;
    }
    """
toks = JCC.tokenize(text)

@testset "tokenizer" begin
    @test toks == [
        JCC.Tokens.Id("int"), JCC.Tokens.Id("main"), JCC.Tokens.Punct("("), JCC.Tokens.Punct(")"),
        JCC.Tokens.Punct("{"),
        JCC.Tokens.Kw("return"), JCC.Tokens.Num(42), JCC.Tokens.Punct(";"),
        JCC.Tokens.Punct("}")
    ]
end

@testset "compile assembly for return 42" begin
    r = JCC.makereader(toks)
    def = JCC.parseFunDef(r)

    # dump assembly to a file
    open("test.s", "w") do f
        JCC.withio(f) do
            JCC.compileprelude()
            JCC.compile(def)
        end
    end

    # compile it with as and ld
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
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
    # TODO fix it
    @test P.parseExpr(r("-3 * (-11 + 4)")) == A.BinaryOp(
        A.UnaryOp(T.Num(3), T.Punct("-")),
        A.ParenExpr(A.BinaryOp(A.UnaryOp(T.Num(11), T.Punct("-")),
                               T.Num(4),
                               T.Punct("+"))),
        T.Punct("*")
    )
end


# Goal: end to end compilation of a program with operators (+
# here)
@testset "operators" begin
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
    @warn "got     : " * JCC.rpn(def)
    @warn "expected: " * JCC.rpn(A.FunDef([T.Id("int")],
                                          A.Decltor(A.DDParams(T.Id("main"),
                                                               [], false)),
                                          A.CmpdStmt([
                                              A.ReturnStmt(A.BinaryOp(T.Num(40),
                                                                      T.Num(2),
                                                                      T.Punct("+")))
                                          ])))
    @test def == A.FunDef([T.Id("int")],
                          A.Decltor(A.DDParams(T.Id("main"),
                                               [], false)),
                          A.CmpdStmt([
                              A.ReturnStmt(A.BinaryOp(T.Num(40),
                                                      T.Num(2),
                                                      T.Punct("+")))
                          ]))

    # dump assembly to a file
    open("test.s", "w") do f
        JCC.withio(f) do
            JCC.compileprelude()
            JCC.compile(def)
        end
    end
    
    # compile it with as and ld
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
end

# Ghuloum step 2 (I know I did it backward ...): unary primitives
@testset "step 2: unary primitives" begin
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
    # dump assembly to a file
    open("test.s", "w") do f
        JCC.withio(f) do
            JCC.compileprelude()
            JCC.compile(def)
        end
    end

    # compile it with as and ld
    run(`as -o test.o test.s`)
    run(`ld -o test test.o`)
    @test run(Cmd(`./test`, ignorestatus=true)).exitcode == 42
end

# Ghuloum step 2 (I know I did it backward ...): unary primitives
@testset "step 2: unary primitives" begin
    text = """
        int main()
        {
            int a = 40;
            int b;
            b = 2;
            return a + b;
        }
        """
    toks = JCC.tokenize(text)
    for t in toks println(t, ",") end
end

