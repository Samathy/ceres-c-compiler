/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module ceres.lexer.lexer;

version (unittest)
{
    import std.stdio : writeln;

    import ceres.lexer.lexer_test_utils : tcase, testLexer, testEmissionState,
        testIntermediateState, testKeywordEmissionState;

    import blerp.blerp;
    static this()
    {
        import core.runtime;
        Runtime.moduleUnitTester = { return true; };
        runTests!(__MODULE__); 
    }
}

import blerp.blerp: BlerpTest;

import std.range.primitives : popFront, empty, isInputRange;
import std.traits : isSomeChar;

//We can use c.isAlpha instead of isAlpha(c)

/* UFCS for char[].front() because 
 * std.range.primitives.front on char[] returns dchar, which is very
 * inconvinient. This is basically copied from std.range.primitives, except
 * with specialiseation on char.
*/
@property ref T front(T)(scope T[] a) @safe pure nothrow @nogc if (is(T == char))
{
    assert(a.length, "Attempted to retrieve front of empty char[]");
    return a[0];
}

@BlerpTest("test_char[]_front()") unittest
{
    char[] c = cast(char[]) "hello";

    assert(c.front() == 'h');
    assert(is(typeof(c.front()) == char));

}


/** 
  * mmrangefile has a current_location method returning a loc. We use char
  * buffers for tests, which need to also have that method.
  *
  */
import ceres.lexer.location: loc;
@property loc current_location(T)(scope T[] a) @safe pure nothrow @nogc if (is(T == char))
{
    loc l;
    return l;
}

@BlerpTest("test_char_buffer_has_current_location") unittest
{
    char[] c = ['a', 'b', 'c', 'd', 'e'];

    assert (is(typeof(c.current_location()) == loc));
}

/**
  *
  */
template lexer(Range, RangeChar)
{
    /**
     * Main lexer class.
     * Starting point for a scan, this class instantiates the start state and
     * while the input stream is not empty, continues stepping to the next state.
     *
     * This lexer is essentially a finite automata model. Using separate classes as each FA state.
     * Each state has logic to decide what token to emit, or which state to go to next.
     * 
     * We can instantiate this lexer using any input range, and character type.
     * Normally this is an mmrangefile ( a memory mapped file )
     */
    class lexer
    {
        import std.conv : to;
        import std.uni : isAlpha;
        import std.range: back;

        import ceres.lexer.mmrangefile;
        import ceres.lexer.token;
        import ceres.lexer.location : loc;
        import ceres.lexer.mmrangefile;

        this(Range f)
        {
            this.f = f;
            this.list = new token_list();
        }

        /** 
          * Enter the start state, 
          * then call the next state until the stream is empty
          */
        void scan(bool early_error = false)
        {
            this.current_state = new state_template!(Range, char).start(this.f, delegate(token t) {
                list.add(t);
            });

            int token_length = 0;

            while (!this.f.empty())
            {
                try
                {
                    if ( this.list.length > token_length)
                    {
                        this.state_graph[].back()[2] = "true"; // If the token list is now longer, the last state emitted a token.
                        token_length++;
                    }
                    this.state_graph ~= [current_state.classinfo.name, to!string(this.f.front()), "false"];

                    current_state = current_state();
                    this.f = current_state.f;
                }
                catch (stateException e)
                {
                    import std.stdio: writeln;
                    writeln("WARN: " ~ e.msg);
                    if (early_error)
                    {
                        throw e;
                    }
                    else
                    {
                        this.f.popFront();
                        this.current_state = new state_template!(Range, char)
                            .start(this.f, delegate(token t) { list.add(t); });
                        continue;
                    }
                }
            }

        }

        token_list get_token_list()
        {
            return this.list;
        }

        string get_state_graph_dot()
        {
            import std.format: format;
            import std.uni: isWhite;
            import ceres.lexer.token: classInfoNameToPlainName;

            string output = "digraph lexer {\n";

            foreach(size_t i, name_and_label; this.state_graph)
            {
                if (i < this.state_graph.length-1)
                {
                    string name = classInfoNameToPlainName(name_and_label[0]);

                    /** Replace whitespace labels with \w */
                    string label;
                    if ( isWhite(name_and_label[1][0]))
                        label = "\\\\w";
                    else
                        label = name_and_label[1];

                    string next_name;
                    next_name = classInfoNameToPlainName(this.state_graph[i+1][0]);
                    
                    /** If the state emitted a token, make it a dashed line */
                    if ( name_and_label[2] == "true")
                        output ~= format("    %s [style=dashed]\n", name);

                    output ~= format("    %s -> %s [label=\"%s\"];\n", name, next_name, label);
                }
            }

            output ~= "}";

            return output;
        }

        private
        {
            string[][] state_graph;

            Range f; // Input range

            token_list list; // List of emitted tokens

            state_template!(Range, RangeChar).state startState; //Start state

            state_template!(Range, RangeChar).state current_state; //Current state

            int line_no;
            int column_no;
        }

    }
}

@BlerpTest("test_lexer") unittest
{
    tcase caseOne = {input: cast(char[]) "if ", emitted_token_count: 1, emits: true};
    tcase caseTwo = {input: cast(char[]) "10 0xDEADBEEF", emitted_token_count: 2};
    tcase caseThree = {
        input: cast(char[]) "001717 if 0x19 ", emitted_token_count: 3};
    tcase caseFour = {
        input: cast(char[]) "0x19 if 0x1010 10 033", emitted_token_count: 5};
    tcase caseFive = {
        input: cast(char[]) "int main() { char wible; unsigned int i = 0x100; float f = 0; }", emitted_token_count: 16};

    tcase[5] testcases = [caseOne, caseTwo, caseThree, caseFour, caseFive];

    testLexer!(char[], char)(testcases);
}

/** 
* Token list contains a list of tokens the lexer has seen.
* It is essentially an array with a range interface.
*/
class token_list
{
    //TODO operator overloading to make this behave like an array too.

    import ceres.lexer.token;

    void add(token t)
    {
        this.list = this.list ~ t;
    }

    bool empty()
    {
        return this.iterator >= this.list.length;
    }

    token front()
    {
        return this.list[this.iterator];
    }

    void popFront()
    {
        this.iterator++;
    }

    size_t length()
    {
        return this.list.length - this.iterator;
    }

    token[] toArray()
    {
        return this.list;
    }

    override string toString()
    {
        string l;
        foreach(t; this.list)
        {
            l~= " "~t.toString();
        }
        return l;
    }

    private
    {
        token[] list;

        int iterator;
    }

}

//Should probably print the symbol we got stuck on.
class stateException : Exception
{
    this(string text)
    {
        super(text);
    }
}

//Can we use some refelction to build a graphviz graph
//of the states, if they report their class names.

/**
* Template for all FA states. 
* Can be instantiated using any input range which uses some kind of character
*/
template state_template(Range, RangeChar)
        if (isInputRange!Range && isSomeChar!RangeChar)
{

    /**
     * The super-state class
     */
    class state
    {
        import ceres.lexer.token;

        /** 
         * Constructor takes the character input range we're operating on, 
         * and a function to call when a token is to be emitted
         */
        this(Range f, void delegate(token t) emission_function)
        {
            this.f = f;
            this.emission_function = emission_function;
        }

        this()
        {
        };

        state opCall()
        in
        {
        }
        body
        {
            return new state(this.f, this.emission_function);
        }

        /**
         * Overridable. Emit a token.
         */
        void emit(token t)
        {
            this.emitted = true;
            this.emission_function(t);
        }

        /**
         * Add a character from the stream to internal buffer 
         * for look-behind in the next state.
         */
        final buffer_char(RangeChar c)
        {
            this.character_buffer ~= c;
        }

        /**
         * Consume a character from the string, but ignore it.
         */
        final state ignore()
        {
            this.f.popFront();
            return this;
        }

        version (unittest)
        {
            /*  
    This conditional comp looks awful, 
    we should figure out
    some way to not be doing this.

    We need access to the character_buffer in 
    the unttests.
    */
            package
            {
                Range f;
                RangeChar[] character_buffer;
                bool emitted = false;
                void delegate(token t) emission_function;
            }
        }
        else
        {
            private
            {
                Range f;
                RangeChar[] character_buffer;
                bool emitted = false;
                void delegate(token t) emission_function;
            }
        }
    }

    /** 
    * Initial starting state
    */
    class start : state
    {
        import std.conv : to;
        import std.uni : isAlpha, isNumber, isWhite, isPunctuation;
        import ceres.lexer.token;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        /**
      * When this state is called, check verious conditions to 
      * choose the next state to jump too
      */
        override state opCall()
        {
            RangeChar c = this.f.front(); //View character

            //If its a normal character
            if (isAlpha(c))
            {
                this.f.popFront();
                auto next_state = new state_template!(Range, RangeChar).isIdentifierOrKeyword(f,
                        this.emission_function);
                next_state.buffer_char(c); //buffer it
                return next_state;
            }
            else if (isNumber(c)) //If number
            {
                this.f.popFront();

                switch (c)
                {
                case '0':
                    if (!this.f.empty)
                    {
                        if ( isNumber(this.f.front()) || this.f.front() == 'x')
                        {
                            auto next_state = new state_template!(Range, RangeChar).isHexOrOct(f,
                                    this.emission_function);
                            next_state.buffer_char(c);
                            return next_state;
                        }
                        else
                        {
                            auto next_state = new state_template!(Range, RangeChar).start(f,
                                    this.emission_function);
                            return next_state;
                        }
                    }
                    else
                    {
                        auto next_state = new state_template!(Range, RangeChar).start(f,
                                this.emission_function);
                        return next_state;
                    }
                case '1': .. case '9':
                    auto next_state = new state_template!(Range,
                            RangeChar).isInteger(this.f, this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                default:
                    throw new stateException("Unexpected Character.");
                }
            }
            else if (isWhite(c)) //Igore whitespace.
            {
                return this.ignore();
            }
            else if (isPunctuation(c))
            {
                this.f.popFront();

                switch (c)
                {
                case ')':
                    auto next_state = new state_template!(Range, RangeChar).isRparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '}':
                    auto next_state = new state_template!(Range, RangeChar).isRparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case ']':
                    auto next_state = new state_template!(Range, RangeChar).isRparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '(':
                    auto next_state = new state_template!(Range, RangeChar).isLparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '{':
                    auto next_state = new state_template!(Range, RangeChar).isLparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '[':
                    auto next_state = new state_template!(Range, RangeChar).isLparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '+':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '-':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '*':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '/':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '=':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '<':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '>':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '^':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '&':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '|':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case ';':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                default:
                    throw new stateException("Unexpected punctuation character.: " ~ c);

                }
            }

            throw new stateException("Unexpected character");
        }
    }

    /** 
    * Process potantial if statement
    * This state is reached after an 'i' is seen
    *
    */
    class isIf : state
    {
        import std.uni : isAlpha, isWhite, isPunctuation;
        import std.range.primitives : back;
        import ceres.lexer.token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            RangeChar c = this.f.front(); //View character

            if (this.character_buffer.back() == 'i' && c == 'f')
            {
                loc l = this.f.current_location;
                l.column_no -= this.character_buffer.length;

                this.character_buffer ~= c;
                this.f.popFront(); //Consume character

                if (!this.f.empty())
                {
                    c = this.f.front();
                }
                else
                {
                    this.emit(new IF(l));
                    return new state_template!(Range, RangeChar).start(this.f,
                            this.emission_function);
                }

                if (isWhite(c) || isPunctuation(c))
                {
                    this.emit(new IF(l));
                    return new state_template!(Range, RangeChar).start(this.f,
                            this.emission_function);
                }
                else
                {
                    //this.f.popFront();
                    auto new_state = new state_template!(Range, RangeChar).isIdentifierOrKeyword(this.f,
                            this.emission_function);
                    new_state.character_buffer = this.character_buffer.dup();
                    return new_state;
                }
            }
            //Do we just have another character?

            else if (isAlpha(c))
            {
                this.f.popFront();
                auto new_state = new state_template!(Range, RangeChar).isIdentifierOrKeyword(this.f,
                        this.emission_function);
                new_state.character_buffer = this.character_buffer.dup();
                return new_state;
            }
            else
            {
                throw new stateException("Unexpected character");
            }

        }
    }

    /**
    * Potential identifier ( variable name etc )
    *
    */
    class isIdentifierOrKeyword : state
    {
        import std.uni : isAlpha, isWhite, isPunctuation;
        import std.conv: to;
        import std.string: toUpper;
        import std.format: format;
        import ceres.lexer.token: getKeywords, keyword, token, ID;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {

            loc l; 
            auto c = this.f.front();
            /* Consume characters until we see one which 
               cant be part of an identifier */
            while (!f.empty())
            {
                c = this.f.front();
                l = this.f.current_location;
                l.column_no -= this.character_buffer.length-1; //Identifiers start at the whitespace

                if (isAlpha(c))
                {
                    this.character_buffer ~= c;
                    this.f.popFront();
                }
                else if (isWhite(c))
                {
                    if(isKeyword(this.character_buffer))
                    {
                        //Don't popfront, let the start state handle that whitespace
                        keyword k = getKeywords[this.character_buffer.toUpper()](l);
                        this.emit(k);
                        break;
                    }
                    else
                    {
                        //Don't popfront, let the start state handle that whitespace
                        this.emit(new ID(l, cast(immutable char[]) this.character_buffer));
                        break;
                    }
                }
                else if (isPunctuation(c))
                {
                    return new state_template!(Range, RangeChar).start(this.f,
                            this.emission_function);
                }
                else
                {
                    throw new stateException(format("%s:%s    Unexpected Character", l.line_no, l.column_no)); //TODO add the character to this error.
                }
            }

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);

        }

        bool isKeyword(char[] word)
        {
            if ( to!string(word.toUpper()) in getKeywords())
            {
                return true;
            }

            return false;

        }

    }

    /** 
    * Potential hex or oct literal
    */
    class isHexOrOct : state
    {
        import ceres.lexer.token;
        import std.format: format;
        
        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
            out //I did have multiple popFront calls in here which was breaking things.
            {
                assert (!this.f.empty(), "isHexOrOct leaves input exhausted");
            }
            do{
                RangeChar c = this.f.front();
                this.f.popFront();

                switch (c)
                {
                case 'x':
                    this.buffer_char(c);
                    auto new_state = new state_template!(Range, RangeChar).isHex(this.f,
                            this.emission_function);
                    new_state.character_buffer = this.character_buffer.dup();
                    return new_state;
                case '0': .. case '7':
                    this.buffer_char(c);
                    auto new_state = new state_template!(Range, RangeChar).isOct(this.f,
                            this.emission_function);
                    new_state.character_buffer = this.character_buffer.dup();

                    return new_state;
                default:
                    loc l = this.f.current_location;
                    throw new stateException(format("%s:%s    Invalid digit in hex or octal constant", l.line_no, l.column_no)); //TODO add the character to this error.
                }
            }
    }

    /**
    * Certainly a hex literal
    */
    class isHex : state
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.range.primitives : back;
        import std.stdio;
        import ceres.lexer.token : hexLiteral, token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            loc l = this.f.current_location;
            l.column_no -= this.character_buffer.length;
            RangeChar c = this.f.front();

            while (!f.empty())
            {
                c = this.f.front();

                if (isHexLetter(c) || isNumber(c))
                {
                    this.character_buffer ~= c;
                }
                else if (isWhite(c) || isPunctuation(c))
                {
                    break;
                }
                else
                {
                    throw new stateException(
                            "Unexpected character. Hexadecimal constant started, but never finished");
                }

                this.f.popFront();
            }

            //If we've only got a 0x then we have a bad hex constant
            if (this.character_buffer.length > 2)
            {
                this.emit(new hexLiteral(l,
                        cast(immutable RangeChar[]) this.character_buffer));
            }
            else
            {
                throw new stateException("Incomplete Hexadecimal character constant");
            }

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
        }

        private
        {
            import std.algorithm : canFind;

            bool isHexLetter(RangeChar c)
            {
                return canFind([
                        'a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D',
                        'E', 'F'
                        ], c);
            }

        }

    }

    /** 
    * Certainly an oct literal
    */
    class isOct : state
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.algorithm : canFind;
        import std.format: format;
        import ceres.lexer.token : octLiteral, token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            loc l  = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            RangeChar c;

            while (!f.empty())
            {

                c = this.f.front();

                if (isNumber(c) && !canFind(['8', '9'], c))
                {
                    this.character_buffer ~= c;
                }
                else if (isWhite(c) || isPunctuation(c))
                {
                    break;
                }
                else
                {
                    throw new stateException(format("%s:%s   Unexpected character in Octal constant: %s", l.line_no, l.column_no, this.character_buffer~c));
                }

                this.f.popFront();
            }
            this.emit(new octLiteral(l, cast(immutable RangeChar[]) this.character_buffer));

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
        }
    }

    /**
    * Certainly an integer literal
    *
    */
    class isInteger : state
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.stdio;
        import std.format: format;
        import ceres.lexer.token : integerLiteral, token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            loc l  = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            RangeChar c;

            while (!f.empty())
            {
                c = this.f.front();
                if (isNumber(c))
                {
                    this.character_buffer ~= c;
                }
                else if (isWhite(c) || isPunctuation(c))
                {
                    break;
                }
                else
                {
                    throw new stateException(format("%s:%s   Badly Formed Integer Constant", l.line_no, l.column_no)); //TODO add the character to this error.
                }

                this.f.popFront();
            }

            this.emit(new integerLiteral(l,
                    cast(immutable RangeChar[]) this.character_buffer));

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
        }
    }

    /** 
     * Right parenthesis
     */
    class isRparen : state
    {
        import std.algorithm : canFind;
        import ceres.lexer.token : rparen, rcurly, rsquare, token;
        import ceres.lexer.location : loc;
        import std.conv: to;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        in
        {
            assert(this.character_buffer.length == 1);
            assert(canFind([')', '}', ']'], this.character_buffer[0]));
        }
        body
        {
            loc l = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            switch (this.character_buffer)
            {
            case ")":
                this.emit(new rparen(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            case "}":
                this.emit(new rcurly(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            case "]":
                this.emit(new rsquare(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            default:
                throw new stateException("Unknown brace type : " ~ to!string(this.character_buffer)); //Please remove this.
            }

            //We already have our char in the buffer, so should be all okay!
            auto new_state = new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
            return new_state;
        }
    }

    /** 
     * Left Parenthesis
     */
    class isLparen : state
    {
        import std.algorithm : canFind;
        import std.conv:to;
        import ceres.lexer.token : lparen, lcurly, lsquare, token;
        import ceres.lexer.location : loc;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        in
        {
            assert(this.character_buffer.length == 1);
            assert(canFind(['(', '{', '['], this.character_buffer[0]));
        }
        body
        {
            loc l = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            switch (this.character_buffer)
            {
            case "(":
                this.emit(new lparen(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            case "{":
                this.emit(new lcurly(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            case "[":
                this.emit(new lsquare(l, cast(immutable RangeChar[]) this.character_buffer));
                break;
            default:
                throw new stateException("Unknown brace type : " ~ to!string(this.character_buffer)); //Please remove this.
            }

            //We already have our char in the buffer, so should be all okay!
            auto new_state = new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
            return new_state;
        }
    }

    /**
     * A mathematical or bitwise operator
     */
    class isOperator : state
    {
        import ceres.lexer.token : semi, mod, lessThan, moreThan, and, or, assign, add, sub, mul, div, token;
        import ceres.lexer.location : loc;

        import std.conv: to;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        in
        {
            assert(this.character_buffer.length == 1);
        }
        body
        {
            loc l = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            switch (this.character_buffer)
            {
            case "+":
                this.emit(new add(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "-":
                this.emit(new sub(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "*":
                this.emit(new mul(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "/":
                this.emit(new div(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "%":
                this.emit(new mod(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "=":
                this.emit(new assign(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case ">":
                this.emit(new moreThan(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "<":
                this.emit(new lessThan(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "&":
                import ceres.lexer.utils: isNewLine;

                if (!this.f.empty && !isNewLine(this.f.front()))
                {
                    if (this.character_buffer[0] == this.f.front())
                    {
                        auto new_state = new state_template!(Range, RangeChar).logical(this.f,
                                this.emission_function);
                        new_state.character_buffer = this.character_buffer;
                        return new_state;
                    }

                }

                this.emit(new and(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case "|":
                import ceres.lexer.utils: isNewLine;

                if (!this.f.empty && !isNewLine(this.f.front()))
                {
                    if (this.character_buffer[0] == this.f.front())
                    {
                        auto new_state = new state_template!(Range, RangeChar).logical(this.f,
                                this.emission_function);
                        new_state.character_buffer = this.character_buffer;
                        return new_state;
                    }

                }

                this.emit(new or(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);

            case ";":
                this.emit(new semi(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            default:
                throw new stateException("Unknown operator: " ~ to!string(this.character_buffer)); //Please remove this.
            }

        }
    }

    /** 
      * A logical operator
      */
    class logical : state
    {

        import ceres.lexer.token : oror, token;
        import ceres.lexer.location : loc;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        in
        {
            assert(this.character_buffer.length == 1);
        }
        body
        {
            loc l = this.f.current_location;
            l.column_no -= this.character_buffer.length;

            RangeChar c = this.f.front();
            this.f.popFront();
            if (this.character_buffer[0] == c)
            {
                string character_pair;
                this.emit(new oror(l, character_pair ~ this.character_buffer[0] ~ c));
            }

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);
        }
    }

}

@BlerpTest("test_start_state") unittest
{

    import std.typecons: tuple, Tuple;

    tcase caseOne = { input:cast(char[]) "i", returns_class: "isIdentifierOrKeyword" };
    tcase caseTwo = { input: cast(char[]) "if (foo", returns_class: "isIdentifierOrKeyword" };
    tcase caseThree = { input: cast(char[]) "ifonlyIcould ", returns_class:"isIdentifierOrKeyword"};
    tcase caseFour = { input: cast(char[]) "0xDEADBEEF", returns_class: "isHexOrOct"};
    tcase caseFive = { input: cast(char[]) "0123456", returns_class: "isHexOrOct"};
    tcase caseSix = { input: cast(char[]) "102937", returns_class: "isInteger" };
    tcase caseSeven = { input: cast(char[]) "10xxx", returns_class: "isInteger", throws: true};

    Tuple!(string,string)[15] punc = [
        tuple(")", "isRparen"), tuple("}", "isRparen"), tuple("]", "isRparen"), 
        tuple("(", "isLparen"),tuple("{", "isLparen"), tuple("[", "isLparen"),
        tuple("+","isOperator"),tuple("-","isOperator"), tuple("=","isOperator"),
        tuple("<","isOperator"),tuple(">","isOperator"),tuple("^","isOperator"),
        tuple("&","isOperator"),tuple("|","isOperator"),tuple(";", "isOperator")];

    tcase[] puncCases;

    //We have lots of punctuation cases that are similar
    foreach(puncTuple;  punc)
    {
        tcase t = { input: cast(char[]) puncTuple[0], returns_class: puncTuple[1],  emits: false};
        puncCases ~= t;
    }

    tcase[] cases = [
        caseOne, caseTwo, caseThree, caseFour, caseFive, caseSix, caseSeven, 
        ];
    cases ~= puncCases;

    testIntermediateState!(state_template!(char[], char).start, char[], char)(cases);
}

@BlerpTest("test_isIf") unittest
{
    tcase caseOne = { input: cast(char[]) "f ", char_buffer_expected: cast(char[])"if", emits:true, emits_class:"IF", prefilled_char_buffer:cast(char[]) "i"};
    tcase caseTwo = { input: cast(char[]) "fxx", char_buffer_expected: cast(char[]) "if", prefilled_char_buffer:cast(char[]) "i" };
    tcase caseThree = { input: cast(char[]) "f;", char_buffer_expected: cast(char[]) "if", emits: true, emits_class: "IF", prefilled_char_buffer:cast(char[]) "i" };
    tcase caseFour = { input: cast(char[]) "f", char_buffer_expected: cast(char[]) "if", emits: true, emits_class: "IF", prefilled_char_buffer: cast(char[]) "i" };

    tcase[] cases = [caseOne, caseTwo, caseThree, caseFour];

    testKeywordEmissionState!(state_template!(char[], char).isIf, char[], char)(cases);
}

@BlerpTest("test_isIdentifier") unittest
{
    import ceres.lexer.token : classInfoNameToPlainName;

    tcase caseOne = {input:cast(char[]) "THING ", char_buffer_expected:cast(char[]) "THING", emits:true, emits_class: "ID" };
    tcase caseTwo = {input:cast(char[]) "THING\n", char_buffer_expected:cast(char[]) "THING", emits: true, emits_class: "ID" };
    tcase caseThree = {input:cast(char[]) " THING", char_buffer_expected:cast(char[]) "",  emits:true, emits_class: "ID"};

    tcase[] cases = [caseOne, caseTwo, caseThree];

    testEmissionState!(state_template!(char[], char).isIdentifierOrKeyword, char[], char)(cases);
}

@BlerpTest("test_isHexOrOct") unittest
{
    import ceres.lexer.token : classInfoNameToPlainName; //ClassInfo.name is the same form as TypeInfo.name

    tcase caseOne = {input:cast(char[]) "x12", returns_class: "isHex", emits:false};
    tcase caseTwo = {input:cast(char[]) "034", returns_class: "isOct", emits: false};
    tcase caseThree = {input:cast(char[]) "9", returns_class: "isOct", throws: true};

    tcase[] cases = [caseOne, caseTwo, caseThree];

    testIntermediateState!(state_template!(char[], char).isHexOrOct, char[], char)(cases);

}

@BlerpTest("test_isHex") unittest
{
    //The first 2 characters would have already been eaten by isOct - so we might not need
    // to check for 0x.
    tcase case1 = {input:cast(char[]) "56FA", char_buffer_expected:cast(char[]) "56FA", emits: true, emits_class: "hexLiteral"};
    tcase case2 = {input:cast(char[]) "000665  ", char_buffer_expected:cast(char[]) "000665", emits: true,emits_class: "hexLiteral"};
    tcase case3 = {input:cast(char[]) "AAB44;", char_buffer_expected:cast(char[]) "AAB44", emits: true,emits_class: "hexLiteral"};
    tcase case4 = {input:cast(char[]) ";", char_buffer_expected:cast(char[]) "", throws: true};
    tcase case5 = {input:cast(char[]) "01x;", char_buffer_expected:cast(char[]) "01", throws: true};
    tcase case6 = {input:cast(char[]) "0334453", char_buffer_expected:cast(char[]) "0334453", throws: true};
    tcase case7 = {input:cast(char[]) "5742227", char_buffer_expected:cast(char[]) "5742227", throws: true};
    tcase case8 = {input:cast(char[]) "0689'993", char_buffer_expected:cast(char[]) "0689993", throws: true};

    tcase[] cases = [case1, case2, case3, case4, case5, case6, case7, case8];

    testEmissionState!(state_template!(char[], char).isHex, char[], char)(cases);
}

@BlerpTest("test_isOct") unittest
{
    tcase case1 = {input:cast(char[]) "1236654", char_buffer_expected:cast(char[]) "1236654", emits: true,emits_class: "octLiteral"};
    tcase case2 = {input:cast(char[]) "00665  ", char_buffer_expected:cast(char[]) "00665", emits: true, emits_class: "octLiteral"};
    tcase case3 = {input:cast(char[]) "0;0665  ", char_buffer_expected:cast(char[]) "0", emits: true, emits_class: "octLiteral"};
    tcase test_commas_in_input = {input:cast(char[]) "005543,", char_buffer_expected:cast(char[]) "005543", emits: true, emits_class: "octLiteral"} ;
    tcase case4 = {input:cast(char[]) "0x10", char_buffer_expected:cast(char[]) "0", throws:true };
    tcase case5 = {input:cast(char[]) "5742227", char_buffer_expected:cast(char[]) "02227", throws: true};
    tcase case6 = {input:cast(char[]) "0689993", char_buffer_expected:cast(char[]) "0689993", throws: true} ;

    tcase[] cases = [case1, case2, case3, case4, case5, case6, test_commas_in_input];

    testEmissionState!(state_template!(char[], char).isOct, char[], char)(cases);
}

@BlerpTest("test_isInteger") unittest
{
    tcase case1 = {input: cast(char[]) "123455", char_buffer_expected: cast(char[]) "123455", emits:true, emits_class: "integerLiteral"};
    tcase case2 = {input:cast(char[]) "9283  ", char_buffer_expected:cast(char[]) "9283", emits:true, emits_class: "integerLiteral"};
    tcase case3 = {input:cast(char[]) "92;83  ", char_buffer_expected:cast(char[]) "92", emits:true, emits_class: "integerLiteral"};
    tcase case4 = {input:cast(char[]) "0x10", char_buffer_expected:cast(char[]) "0x10", throws: true} ;
    tcase case5 = {input:cast(char[]) "02227", char_buffer_expected:cast(char[]) "02227", throws:true};

    tcase[] cases = [case1, case2, case3, case4, case5];

    testEmissionState!(state_template!(char[], char).isInteger, char[], char)(cases);
}

@BlerpTest("test_isRparen") unittest
{
    tcase caseOne = { input: cast(char[]) ")", char_buffer_expected: cast(char[]) ")",  emits: true, emits_class: "rparen", prefilled_char_buffer: cast(char[]) ")"};
    tcase caseTwo = { input: cast(char[]) "}", char_buffer_expected: cast(char[]) "}", emits: true, emits_class: "rcurly", prefilled_char_buffer: cast(char[]) "}"};
    tcase caseThree = { input: cast(char[]) "]", char_buffer_expected: cast(char[]) "]", emits: true, emits_class: "rsquare", prefilled_char_buffer: cast(char[]) "]" };
    tcase caseFour = {input: cast(char[]) "i", throws: true };

    tcase[] cases = [caseOne, caseTwo, caseThree, caseFour];

    testEmissionState!(state_template!(char[], char).isRparen, char[], char)(cases);
}

@BlerpTest("test_isLparen") unittest
{
    tcase caseOne = { input: cast(char[]) "(", char_buffer_expected: cast(char[]) "(", emits: true, emits_class: "lparen", prefilled_char_buffer: cast(char[]) "(" };
    tcase caseTwo = { input: cast(char[]) "{", char_buffer_expected: cast(char[]) "{", emits: true, emits_class: "lcurly", prefilled_char_buffer: cast(char[]) "{" };
    tcase caseThree = { input: cast(char[]) "[", char_buffer_expected: cast(char[]) "[", emits: true, emits_class: "lsquare", prefilled_char_buffer: cast(char[]) "[" };
    tcase caseFour = {input: cast(char[]) "i", throws: true };

    tcase[] cases = [caseOne, caseTwo, caseThree, caseFour];

    testEmissionState!(state_template!(char[], char).isLparen, char[], char)(cases);
}

@BlerpTest("test_isOct") unittest
{
    tcase caseOne = { input: cast(char[]) " 10", throws: false, emits: true, emits_class: "add", prefilled_char_buffer: cast(char[]) "+", char_buffer_expected: cast(char[]) "+" };

    tcase[] cases = [caseOne];

    testEmissionState!(state_template!(char[], char).isOperator, char[], char)(cases);
}

@BlerpTest("test_isOperator")  unittest
{
    import std.typecons: Tuple, tuple;
    Tuple!(string,string)[] punc = [
        tuple("+", "add"), tuple("-", "sub"), tuple("*", "mul"), 
        tuple("/", "div"),tuple("%", "mod"), tuple("=", "assign"),
        tuple(">","moreThan"),tuple("<","lessThan"), tuple("&","and"),
        tuple("|","or"), tuple(";", "semi")];

    tcase[] puncCases;

    //We have lots of punctuation cases that are similar
    foreach(puncTuple;  punc)
    {
        tcase t = { prefilled_char_buffer: cast(char[]) puncTuple[0],  emits: true, emits_class: puncTuple[1]};
        puncCases ~= t;
    }

    tcase caseOne = { input: cast(char[]) "|", char_buffer_expected: cast(char[]) "|", returns_class: "logical", prefilled_char_buffer: cast(char[]) "|"};
    tcase caseTwo = { input: cast(char[]) "&", char_buffer_expected: cast(char[]) "&", returns_class: "logical" , prefilled_char_buffer: cast(char[]) "&"};

    tcase[] intermediate_cases = [caseOne, caseTwo];
    tcase[] cases;
    cases ~= puncCases;

    //testEmissionState!(state_template!(char[], char).isOperator, char[], char)(cases);

    testIntermediateState!(state_template!(char[], char).isOperator, char[], char)(intermediate_cases);
    
}


