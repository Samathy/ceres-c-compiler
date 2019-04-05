module c_lex.token;

import std.string : toUpper, lastIndexOf;

import c_lex.location : loc;

/// Takes a class name as stored and returns a plain class name.
string classInfoNameToPlainName(string classinfoName)
{
    string noPrefix = classinfoName[lastIndexOf(classinfoName, ".") + 1 .. classinfoName.length];
    long bracket = lastIndexOf(noPrefix, "(");

    if (bracket != -1)
    {
        return noPrefix[0 .. bracket];
    }
    else
    {
        return noPrefix;
    }
}

unittest
{
    import std.stdio;

    assert(classInfoNameToPlainName("C_LEX.TOKEN.TOKEN()") == "TOKEN");
    assert(classInfoNameToPlainName("C_LEX.TOKEN.TOKEN") == "TOKEN");
}

class token
{
    this(loc location)
    {
        this.location = location;
        this.type_string = classInfoNameToPlainName(toUpper(this.classinfo.name));
    }

    override string toString()
    {
        return this.type_string;
    }

    private
    {
        loc location;
        immutable string type_string;
    }
}

unittest
{
    auto t = new token(loc(10, 10, "foo.c"));

    assert(t.toString() == "TOKEN");
}

class id : token
{
    this(loc location, string token_string)
    {
        super(location);
        this.token_string = token_string;
    }

    override string toString()
    {
        return this.type_string ~ "(" ~ this.token_string ~ ")";
    }

    private
    {
        string token_string;
    }
}

unittest
{
    auto t = new id(loc(10, 10, "foo.c"), "foo");

    assert(t.toString() == "ID(foo)");
}

abstract class paren : token
{
    this(loc location, string token_string)
    {
        this(location, token_string, this.allowed_parenthesis);
    }

    this(loc location, string token_string, immutable string[] parenthesis)
    {
        import std.algorithm : canFind;

        super(location);
        if (canFind(parenthesis, token_string))
        {
            this.token_string = token_string;
        }
        else
        {
            import std.conv : to;
            import std.string;

            //TODO Could add a helper function to print the allowed parenthesis with English joiners.
            throw new Exception(classInfoNameToPlainName(this.classinfo.name)
                    ~ " class cannot be instantiated with something that isnt: " ~ to!string(
                        parenthesis));
        }
    }

    override string toString()
    {
        return this.type_string ~ "(" ~ this.token_string ~ ")";
    }

    private
    {
        string token_string;
        immutable string[] allowed_parenthesis = ["(", ")", "[", "]", "{", "}"];
    }
}

class rparen : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = [")", "]", "}"];
    }
}

unittest
{
    auto t = new rparen(loc(10, 10, "foo.c"), ")");

    assert(t.toString() == "RPAREN())");
}

unittest
{
    try
    {
        auto t = new rparen(loc(10, 10, "foo.c"), "(");
    }
    catch (Exception e)
    {
        assert(true);
    }
}

class lparen : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = ["(", "[", "{",];
    }
}

unittest
{
    auto t = new lparen(loc(10, 10, "foo.c"), "(");

    assert(t.toString() == "LPAREN(()");
}

unittest
{
    try
    {
        auto t = new lparen(loc(10, 10, "foo.c"), ")");
    }
    catch (Exception e)
    {
        assert(true);
    }
}

class integer : token
{
    this(loc location, string token_string)
    {
        super(location);
        this.token_string = token_string;
    }

    private
    {
        string token_string;
    }
}

class boolean : token
{
    this(loc location, string token_string)
    {
        super(location);
        this.token_string = token_string;
    }

    private
    {
        string token_string;
    }
}

abstract class operator : token
{
    this(loc location, string token_string)
    {
        this(location, token_string, this.allowed_operators);
    }

    this(loc location, string token_string, immutable string[] operators)
    {
        import std.algorithm : canFind;

        super(location);
        if (canFind(operators, token_string))
        {
            this.token_string = token_string;
        }
        else
        {
            import std.conv : to;
            import std.string;

            //TODO Could add a helper function to print the allowed parenthesis with English joiners.
            throw new Exception(classInfoNameToPlainName(
                    this.classinfo.name) ~ " class cannot be instantiated with something that isnt: " ~ to!string(
                    operators));
        }
    }

    override string toString()
    {
        return this.type_string ~ "(" ~ this.token_string ~ ")";
    }

    private
    {
        immutable string[] allowed_operators = ["+", "-", "/", "*", "%"];
        string token_string;
    }
}

class plus : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, this.allowed_operators);
    }

    private
    {
        immutable string[] allowed_operators = ["+"];
        string token_string;
    }
}

unittest
{
    auto t = new plus(loc(10, 10, "foo.c"), "+");

    assert(t.toString() == "PLUS(+)");
}
