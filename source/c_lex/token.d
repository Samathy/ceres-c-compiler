/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module c_lex.token;

import std.string : toUpper, lastIndexOf;

import c_lex.location : loc;

/**
  * We need to rename some of these tokens so they are actually the tokens of the C language
  */

/** 
  * Function to convert class names into plain names
  * for printing and comparason in tests.
  */
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

/** 
  * Token superclass
  */
class token
{
    /** 
      * Constructor takes a location struct to track where the token came from
      */
    this(loc location)
    {
        this.location = location;
        this.type_string = classInfoNameToPlainName(toUpper(this.classinfo.name));
    }

    /** 
      * Overridable method to print the token name, and optionally the string
      * which generated the token. (i.e ID(somevarname))
      */
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

/** 
  * subclass token as a for keywords
  */
class keyword : token
{
    this(loc location)
    {
        super(location);
    }
}

class IF : keyword
{

    this(loc location)
    {
        super(location);
    }

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

/** 
  * Abstract base for parenthesis tokens
  */
abstract class paren : token
{
    this(loc location, string token_string)
    {
        this(location, token_string, this.allowed_parenthesis);
    }

    /** 
      * parent constructor takes a location, the string which generated the
      * token, and a list if characters which are allowed to be considered
      * parenthesis tokens.
      */
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
    auto t = new integer(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "INTEGER(10)");
}

class hexInteger : integer
{
    this(loc location, string token_string)
    {
        super(location, token_string);
    }

}

unittest
{
    auto t = new hexInteger(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "HEXINTEGER(10)");
}

class octInteger : integer
{
    this(loc location, string token_string)
    {
        super(location, token_string);
    }

}

unittest
{
    auto t = new octInteger(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "OCTINTEGER(10)");
}

class boolean : token
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
    auto t = new boolean(loc(10, 10, "foo.c"), "true");

    assert(t.toString() == "BOOLEAN(true)");
}

class operator : token
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

class comparason : token
{
    this(loc location, string token_string)
    {
        this.token_string = token_string;
        super(location);
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
    auto t = new comparason(loc(10, 10, "foo.c"), "=");

    import std.stdio : writeln;

    assert(t.toString() == "COMPARASON(=)");
}

class punctuator : token
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
    auto t = new punctuator(loc(10, 10, "foo.c"), ";");

    assert(t.toString() == "PUNCTUATOR(;)");
}
