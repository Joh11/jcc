export Token, tokenize

struct Num
    n :: Int
end

struct Id
    str :: String
end

struct Punct
    str :: String
end

struct Kw
    str :: String
end

struct EOF end

const Token = Union{Num, Id, Punct, Kw, EOF}

Base.show(io::IO, x::Num) = print(io, "\$$(x.n)")
Base.show(io::IO, x::Id) = print(io, "<$(x.str)>")

# see 6.4.6
const punctfirst = "[](){}.-+&*~!/%<>=^|?:;,#"

function tokenize(text)
    tokens = Token[]
    i = 1

    while i <= length(text)
        # skip whitespaces
        if isspace(text[i]) i += 1; continue end

        if isdigit(text[i]) # start parsing a numeral
            token = string(text[i])
            i += 1
            while i <= length(text) && isdigit(text[i])
                token *= text[i]
                i += 1
            end
            push!(tokens, Num(parse(Int, token)))
            # TODO put other punctuators
        elseif text[i] in punctfirst
            token, i = tokenizepunct(text, i)
            push!(tokens, token)
            # i += 1
        elseif isnondigit(text[i])
            token = string(text[i])
            i += 1 # 1st char cannot be a digit, but the others yes
            while i <= length(text) && (isnondigit(text[i]) || isdigit(text[i]))
                token *= text[i]
                i += 1
            end

            # discriminate between identifiers and keywords
            push!(tokens, iskeyword(token) ? Kw(token) : Id(token))
        else
            error("unhandled character $(text[i])")
        end
    end
    tokens
end

"as defined in the standard, A.1.3"
function isnondigit(c)
    c == '_' || isletter(c)
end

function iskeyword(str)
    # TODO put all A.1.2
    str in ["return"]
end

function tokenizepunct(text, i) :: Tuple{Punct, Int64}
    # see 6.4.6
    @assert text[i] in punctfirst
    
    # the only 4 char punctuator
    if i+3 <= length(text) && text[i:i+3] == "%:%:"
        # convert the digraphs directly it will be simpler
        return Punct("##"), i+4
    end
    
    if i+2 <= length(text) && text[i:i+2] in ["...", "<<=", ">>="]
        return Punct(text[i:i+2]), i+3
    end
    
    if i+1 <= length(text)
        # deal with digraphs first
        p = text[i:i+1]
        if p in ["<:", ":>", "<%", "%>", "%:"]
            return Punct(Dict("<:" => "[", ":>" => "]",
                              "<%" => "{", "%>" => "}",
                              "%:" => "#")[p]), i+2
        end
        
        p2 = [
            "->",
            "++", "--",
            "<<", ">>", "<=", ">=", "==", "!=", "&&", "||",
            "*=", "/=", "%=", "+=", "-=", "&=", "^=", "|=",
            "##"
        ]
        
        if p in p2 return (Punct(p), i+2) end
    end
    
    Punct(text[i:i]), i+1
end
