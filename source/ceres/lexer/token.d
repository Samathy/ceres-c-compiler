/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module ceres.lexer.token;

import std.string : toUpper, lastIndexOf, format;

import ceres.lexer.location : loc;
import ceres.lexer.utils : getTypes;

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
  * A compile-time map of keyword class factories to a string of their name.
  */
static enum keyword function(loc...)[string] keywords = getTypes!(keyword, __MODULE__, 1, loc);

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
    override string toString()
    {
        return format("%s:%s    %s", this.location.line_no,
                this.location.column_no, this.type_string);
    }
    */

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

/** Subclass for keywords representing types
  */
class typename : keyword
{
    this(loc location)
    {
        super(location);
    }
}

/** Subclass for specifiers on typenames 
  like 'long' or 'unsigned' that combine with a basic
  type-name to make a full typename
  */
class typespecifer : typename
{
    this(loc location)
    {
        super(location);
    }
}

/** Type qualifiers like 'const'*/
class typequalifier: keyword
{
    this(loc location)
    {
        super(location);
    }
}

/** storage classes like 'volatile' or 'register' */
class storageclass: keyword
{
    this(loc location)
    {
        super(location);
    }
}



class AUTO : storageclass
{

    this(loc location)
    {
        super(location);
    }

}

class BREAK : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class CASE : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class CHAR : typename
{

    this(loc location)
    {
        super(location);
    }

}

class CONST : typequalifier
{

    this(loc location)
    {
        super(location);
    }

}

class CONTINUE : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class DEFAULT : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class DO : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class DOUBLE : typename
{

    this(loc location)
    {
        super(location);
    }

}

class ELSE : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class ENUM : typename
{

    this(loc location)
    {
        super(location);
    }

}

class EXTERN : storageclass
{

    this(loc location)
    {
        super(location);
    }

}

class FLOAT : typename
{

    this(loc location)
    {
        super(location);
    }

}

class FOR : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class GOTO : keyword
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

class INLINE : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class INT : typename
{

    this(loc location)
    {
        super(location);
    }

}

class LONG : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class REGISTER : storageclass
{

    this(loc location)
    {
        super(location);
    }

}

class RESTRICT : typequalifier
{

    this(loc location)
    {
        super(location);
    }

}

class RETURN : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class SHORT : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class SIGNED : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class SIZEOF : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class STATIC : storageclass
{

    this(loc location)
    {
        super(location);
    }

}

class STRUCT : typename
{

    this(loc location)
    {
        super(location);
    }

}

class SWITCH : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class TYPEDEF : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class UNION : typename
{

    this(loc location)
    {
        super(location);
    }

}

class UNSIGNED : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class VOID : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class VOLATILE : typequalifier
{

    this(loc location)
    {
        super(location);
    }

}

class WHILE : keyword
{

    this(loc location)
    {
        super(location);
    }

}

class _BOOL : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class _COMPLEX : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class _IMAGINARY : typespecifer
{

    this(loc location)
    {
        super(location);
    }

}

class ID : token
{
    this(loc location, string token_string)
    {
        super(location);
        this.token_string = token_string;
    }

    override string toString()
    {
        return format("%s:%s    %s (%s)", this.location.line_no,
                this.location.column_no, this.type_string, this.token_string);
    }

    private
    {
        string token_string;
    }
}

unittest
{
    auto t = new ID(loc(10, 10, "foo.c"), "foo");

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
        immutable string[] allowed_parenthesis = [")"];
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
        immutable string[] allowed_parenthesis = ["("];
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

class lcurly : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = ["{",];
    }
}

class rcurly : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = ["}",];
    }
}

class lsquare : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = ["["];
    }
}

class rsquare : paren
{

    this(loc location, string token_string)
    {
        import std.algorithm : canFind;

        super(location, token_string, this.allowed_parenthesis);
    }

    private
    {
        immutable string[] allowed_parenthesis = ["]"];
    }
}

//TODO numerical constants can have suffixes, which we're not dealing with atm.

enum integerSign
{
    POSITIVE,
    NEGATIVE
}

class integerLiteral : token
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
    auto t = new integerLiteral(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "INTEGERLITERAL(10)");
}

class signedIntegerLiteral : integerLiteral
{
    this(loc location, integerSign sign, string token_string)
    {
        this.sign = sign;
        super(location, token_string);
    }

    public
    {
        integerSign sign;
    }

}

class hexLiteral : integerLiteral
{
    this(loc location, string token_string)
    {
        super(location, token_string);
    }
}

unittest
{
    auto t = new hexLiteral(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "HEXLITERAL(10)");
}

class octLiteral : integerLiteral
{
    this(loc location, string token_string)
    {
        super(location, token_string);
    }

}

unittest
{
    auto t = new octLiteral(loc(10, 10, "foo.c"), "10");

    assert(t.toString() == "OCTLITERAL(10)");
}

class decLiteral : integerLiteral
{
    this(loc location, string token_string)
    {
        super(location, token_string);
    }
}

class floatLiteral : token
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

    /**
    override string toString()
    {
        return this.type_string ~ "(" ~ this.token_string ~ ")";
    }
    **/

    private
    {
        immutable string[] allowed_operators = ["+", "-", "/", "*", "%"];
        string token_string;
    }
}

class unary_operator: operator
{
    this(loc location, string token_string, string[] allowed_operators)
    {
        super(location, token_string);
    }
}

class equal : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["=="]);
    }
}

class not : unary_operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["!"]);
    }
}

class add : unary_operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["+"]);
    }
}

class sub : unary_operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["-"]);
    }
}

class div : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["/"]);
    }
}

class mod : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["%"]);
    }
}

class mul : unary_operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["*"]);
    }
}

class lshift : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["<<"]);
    }
}

class rshift : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, [">>"]);
    }
}

class assign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["="]);
    }
}

class andAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["+="]);
    }
}

class orAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["&="]);
    }
}

class xorAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["^="]);
    }
}

class addAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["+="]);
    }
}

class minAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["-="]);
    }
}

class divAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["/="]);
    }
}

class mulAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["*="]);
    }
}

class modAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["%="]);
    }
}

class lshiftAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["<<="]);
    }
}

class rshiftAssign : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, [">>="]);
    }
}

class and : unary_operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["&"]);
    }
}

class or : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["|"]);
    }
}

class xor : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["^"]);
    }
}

class andand : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["&&"]);
    }
}

class oror : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["||"]);
    }
}

class minusminus : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["--"]);
    }
}

class plusplus : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["++"]);
    }
}

class moreThan : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, [">"]);
    }
}

class lessThan : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["<"]);
    }
}

class lessThanEqualTo : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["<="]);
    }
}

class moreThanEqualTo : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, [">="]);
    }
}

class notEqualTo : operator
{
    this(loc location, string token_string)
    {
        super(location, token_string, ["!="]);
    }
}

class semi : token
{
    this(loc location, string token_string)
    {
        super(location);
    }
}

class comma : token
{
    this(loc location, string token_string)
    {
        super(location);
    }
}

class stop : token
{
    this(loc location, string token_string)
    {
        super(location);
    }
}

class stringLiteral : token
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
