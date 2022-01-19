include("main.jl")
using .JCC

using Test

# Step 1 from Ghuloum

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
    r(str) = JCC.Parse.makereader(JCC.Tokens.tokenize(str))
    @test JCC.Parse.parsePrimExpr(r("42 f")) == JCC.Tokens.Num(42)
    @test JCC.Parse.parsePrimExpr(r("f 42")) == JCC.Tokens.Id("f")
    @test_throws ErrorException JCC.Parse.parsePrimExpr(r(";42"))
    
    @test JCC.Parse.parseAddExpr(r("42 + 4")) == JCC.AST.BinaryOp(JCC.Tokens.Num(42), JCC.Tokens.Num(4), JCC.Tokens.Punct("+"))
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
    @test def == JCC.AST.FunDef(JCC.Tokens.Id("int"),
                                JCC.AST.Decltor(JCC.Tokens.Id("main"), JCC.AST.ParamDecl[]),
                                JCC.AST.CmpdStmt([
                                    JCC.AST.ReturnStmt(JCC.AST.BinaryOp(JCC.Tokens.Num(40),
                                                                        JCC.Tokens.Num(2),
                                                                        JCC.Tokens.Punct("+")))
                                ]))

end

