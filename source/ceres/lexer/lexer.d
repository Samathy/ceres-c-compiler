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
}

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

unittest
{
    char[] c = cast(char[]) "hello";

    assert(c.front() == 'h');
    assert(is(typeof(c.front()) == char));

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

            while (!this.f.empty())
            {
                try
                {
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

        private
        {
            Range f; // Input range

            token_list list; // List of emitted tokens

            state_template!(Range, RangeChar).state startState; //Start state

            state_template!(Range, RangeChar).state current_state; //Current state

            int line_no;
            int column_no;
        }

    }
}

unittest
{
    tcase caseOne = {input: cast(char[]) "if", emitted_token_count: 1};
    tcase caseTwo = {input: cast(char[]) "10 0xDEADBEEF", emitted_token_count: 2};
    tcase caseThree = {
        input: cast(char[]) "001919, if, 0x19 ", emitted_token_count: 2};
    tcase caseFour = {
        input: cast(char[]) "0x19 if 0x1010 10 033", emitted_token_count: 5};

    tcase[2] testcases = [caseOne, caseTwo];

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
                switch (c) //Check for the first character of each keyword.
                {
                    //TODO Can we generate this switch statement from a list of keywords?
                case 'i':
                    this.f.popFront(); //Consume character
                    auto next_state = new state_template!(Range, RangeChar).isIf(f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                default:
                    auto next_state = new state_template!(Range, RangeChar).isIdentifier(f,
                            this.emission_function);
                    next_state.buffer_char(c); //buffer it
                    return next_state;
                }

            }
            else if (isNumber(c)) //If number
            {
                this.f.popFront();

                switch (c)
                {
                case '0':
                    auto next_state = new state_template!(Range, RangeChar).isHexOrOct(f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
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
                case '}':
                case ']':
                    auto next_state = new state_template!(Range, RangeChar).isRparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '(':
                case '{':
                case '[':
                    auto next_state = new state_template!(Range, RangeChar).isLparen(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '+':
                case '-':
                case '=':
                    auto next_state = new state_template!(Range, RangeChar).isOperator(this.f,
                            this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;

                case '<':
                case '>':
                case '^':
                case '&':
                case '|':
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
                    this.f.popFront();
                    auto new_state = new state_template!(Range, RangeChar).isIdentifier(this.f,
                            this.emission_function);
                    new_state.character_buffer = this.character_buffer.dup();
                    return new_state;
                }
            }
            //Do we just have another character?

            else if (isAlpha(c))
            {
                this.f.popFront();
                auto new_state = new state_template!(Range, RangeChar).isIdentifier(this.f,
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
    class isIdentifier : state
    {
        import std.uni : isAlpha, isWhite, isPunctuation;
        import ceres.lexer.token;
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
                    //Don't popfront, let the start state handle that whitespace
                    this.emit(new ID(l, cast(immutable char[]) this.character_buffer));
                    break;
                }
                else if (isPunctuation(c))
                {
                    return new state_template!(Range, RangeChar).start(this.f,
                            this.emission_function);
                }
                else
                {
                    throw new stateException("Unexpected character");
                }
            }

            return new state_template!(Range, RangeChar).start(this.f,
                    this.emission_function);

        }

    }

    /** 
    * Potential hex or oct literal
    */
    class isHexOrOct : state
    {
        import ceres.lexer.token;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            RangeChar c = this.f.front();

            switch (c)
            {
            case 'x':
                this.f.popFront();
                this.buffer_char(c);
                auto new_state = new state_template!(Range, RangeChar).isHex(this.f,
                        this.emission_function);
                new_state.character_buffer = this.character_buffer.dup();
                return new_state;
            case '0': .. case '7':
                this.f.popFront();
                this.buffer_char(c);
                auto new_state = new state_template!(Range, RangeChar).isOct(this.f,
                        this.emission_function);
                new_state.character_buffer = this.character_buffer.dup();
                return new_state;
            default:
                throw new stateException("Invalid digit in hex or octal constant"); //TODO add the character to this error.
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
        import ceres.lexer.token : octLiteral, token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {
            auto c = this.f.front();

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
                    throw new stateException("Unexpected character. Invalid Hex constant");
                }

                this.f.popFront();
            }

            loc l;
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
        import ceres.lexer.token : integerLiteral, token;
        import ceres.lexer.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state opCall()
        {

            RangeChar c = this.f.front();

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
                    throw new stateException(
                            "Unexpected character. Badly formed integer constant");
                }

                this.f.popFront();
            }

            loc l;
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
            loc l;

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
                throw new stateException("Unknown brace type : " ~ this.character_buffer[0]); //Please remove this.
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
            loc l;

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
                throw new stateException("Unknown brace type : " ~ this.character_buffer[0]); //Please remove this.
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
        import ceres.lexer.token : mod, lessThan, moreThan, or, assign, add, sub, token;
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
            loc l;

            switch (this.character_buffer[0])
            {
            case '+':
                this.emit(new add(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '-':
                this.emit(new sub(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '%':
                this.emit(new mod(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '=':
                this.emit(new assign(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '>':
                this.emit(new moreThan(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '<':
                this.emit(new lessThan(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '&':
                this.emit(new or(l, cast(immutable char[]) this.character_buffer));
                return new state_template!(Range, RangeChar).start(this.f,
                        this.emission_function);
            case '|':
                if (this.character_buffer[0] == this.f.front())
                {
                    auto new_state = new state_template!(Range, RangeChar).logical(this.f,
                            this.emission_function);
                    new_state.character_buffer = this.character_buffer;
                    return new_state;
                }
                else
                {
                    this.emit(new or(l, cast(immutable char[]) this.character_buffer));
                    return new state_template!(Range, RangeChar).start(this.f,
                            this.emission_function);
                }
            default:
                throw new stateException("Unknown operator: " ~ this.character_buffer[0]); //Please remove this.
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
            loc l;
            auto c = this.f.front();
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

unittest
{

    tcase caseOne = {
        cast(char[]) "i", cast(char[]) "isIf", false, false, "", cast(char[]) ""
        };
    tcase caseTwo = {
        cast(char[]) "if (foo", cast(char[]) "isIf", false, false, "", cast(char[]) ""
        };
    tcase caseThree = {
        cast(char[]) "ifonlyIcould ", cast(char[]) "isIf", false, false, "", cast(char[]) ""
        };
    tcase caseFour = {
        cast(char[]) "0xDEADBEEF", cast(char[]) "isHexOrOct", false,
            false, "", cast(char[]) ""
        };
    tcase caseFive = {
        cast(char[]) "0123456", cast(char[]) "isHexOrOct", false, false, "", cast(char[]) ""
        };
    tcase caseSix = {
        cast(char[]) "102937", cast(char[]) "isInteger", false, false, "", cast(char[]) ""
        };
    tcase caseSeven = {
        cast(char[]) "10xxx", cast(char[]) "isInteger", true, false, "", cast(char[]) ""
    };

    tcase[7] cases = [
        caseOne, caseTwo, caseThree, caseFour, caseFive, caseSix, caseSeven
        ];

    testIntermediateState!(state_template!(char[], char).start, char[], char)(cases);
}

unittest
{
    tcase caseOne = {
        cast(char[]) "f ", cast(char[]) "if", false, true, "start", cast(char[]) "i"
        };
    tcase caseTwo = {
        cast(char[]) "fxx", cast(char[]) "if", false, false, "isIdentifier", cast(char[]) "i"
        };
    tcase caseThree = {
        cast(char[]) "f;", cast(char[]) "if", false, true, "start", cast(char[]) "i"
        };
    tcase caseFour = {
        cast(char[]) "f", cast(char[]) "if", false, true, "start", cast(char[]) "i"
        };

    tcase[4] cases = [caseOne, caseTwo, caseThree, caseFour];

    testKeywordEmissionState!(state_template!(char[], char).isIf, char[], char)(cases);
}

unittest
{
    import ceres.lexer.token : classInfoNameToPlainName;

    tcase caseOne = {cast(char[]) "THING ", cast(char[]) "THING", false, true
        };
    tcase caseTwo = {cast(char[]) "THING\n", cast(char[]) "THING", false, true
        };
    tcase caseThree = {cast(char[]) " THING", cast(char[]) "", false, true};

    tcase[3] cases = [caseOne, caseTwo, caseThree];

    testEmissionState!(state_template!(char[], char).isIdentifier, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for isHexOrOct");
    import ceres.lexer.token : classInfoNameToPlainName; //ClassInfo.name is the same form as TypeInfo.name

    tcase caseOne = {cast(char[]) "x12", cast(char[]) "isHex", false, true};
    tcase caseTwo = {cast(char[]) "034", cast(char[]) "isOct", false, true};
    tcase caseThree = {cast(char[]) "9", cast(char[]) "isOct", true, false};

    tcase[3] cases = [caseOne, caseTwo, caseThree];

    testIntermediateState!(state_template!(char[], char).isHexOrOct, char[], char)(cases);

}

unittest
{
    writeln("Running test cases for isHex");

    //The first 2 characters would have already been eaten by isOct - so we might not need
    // to check for 0x.
    tcase case1 = {cast(char[]) "56FA", cast(char[]) "56FA", false, true};
    tcase case2 = {cast(char[]) "000665  ", cast(char[]) "000665", false, true};
    tcase case3 = {cast(char[]) "AAB44;", cast(char[]) "AAB44", false, true};
    tcase case4 = {cast(char[]) ";", cast(char[]) "", true, false};
    tcase case5 = {cast(char[]) "01x;", cast(char[]) "01", true, false};
    tcase case6 = {cast(char[]) "0334453", cast(char[]) "0334453", true, false};
    tcase case7 = {cast(char[]) "5742227", cast(char[]) "5742227", true, false};
    tcase case8 = {cast(char[]) "0689'993", cast(char[]) "0689993", true, false};

    tcase[8] cases = [case1, case2, case3, case4, case5, case6, case7, case8];

    testEmissionState!(state_template!(char[], char).isHex, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for isOct");

    tcase case1 = {cast(char[]) "1236654", cast(char[]) "1236654", false, true};
    tcase case2 = {cast(char[]) "00665  ", cast(char[]) "00665", false, true};
    tcase case3 = {cast(char[]) "0;0665  ", cast(char[]) "0", false, true};
    tcase case4 = {cast(char[]) "0x10", cast(char[]) "0", true, false};
    tcase case5 = {cast(char[]) "5742227", cast(char[]) "02227", true, false};
    tcase case6 = {cast(char[]) "0689993", cast(char[]) "0689993", true, false};

    tcase[6] cases = [case1, case2, case3, case4, case5, case6];

    testEmissionState!(state_template!(char[], char).isOct, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for isInteger");

    tcase case1 = {cast(char[]) "123455", cast(char[]) "123455", false, true};
    tcase case2 = {cast(char[]) "9283  ", cast(char[]) "9283", false, true};
    tcase case3 = {cast(char[]) "92;83  ", cast(char[]) "92", false, true};
    tcase case4 = {cast(char[]) "0x10", cast(char[]) "0x10", true, false};
    tcase case5 = {cast(char[]) "02227", cast(char[]) "02227", true, false};

    tcase[5] cases = [case1, case2, case3, case4, case5];

    testEmissionState!(state_template!(char[], char).isInteger, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for isRparen");

    tcase caseOne = {
        input: cast(char[]) ")", char_buffer_expected: cast(char[]) ")", throws: false, emits: true,
        emits_class: "rparen", emitted_token_count: 1, prefilled_char_buffer: cast(char[]) ")"};
        tcase caseTwo = {
            input: cast(char[]) "}", char_buffer_expected: cast(char[]) "}", throws: false, emits: true, emits_class: "rparen",
            emitted_token_count: 1, prefilled_char_buffer: cast(char[]) "}"};
            tcase caseThree = {
                input: cast(char[]) "]", char_buffer_expected: cast(char[]) "]",
                throws: false, emits: true, emits_class: "rparen",
                emitted_token_count: 1, prefilled_char_buffer: cast(char[]) "]"
    };
    tcase caseFour = {input: cast(char[]) "i", throws: true
        };

    tcase[4] cases = [caseOne, caseTwo, caseThree, caseFour];

    testEmissionState!(state_template!(char[], char).isRparen, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for is isLparen");

    tcase caseOne = {
        input: cast(char[]) "(", char_buffer_expected: cast(char[]) "(", throws: false, emits: true,
        emits_class: "lparen", emitted_token_count: 1, prefilled_char_buffer: cast(char[]) "("
        };
    tcase caseTwo = {
        input: cast(char[]) "{", char_buffer_expected: cast(char[]) "{", throws: false, emits: true, emits_class: "lparen",
        emitted_token_count: 1, prefilled_char_buffer: cast(char[]) "{"
        };
    tcase caseThree = {
        input: cast(char[]) "[", char_buffer_expected: cast(char[]) "[",
        throws: false, emits: true, emits_class: "lparen",
        emitted_token_count: 1, prefilled_char_buffer: cast(char[]) "["
        };
    tcase caseFour = {input: cast(char[]) "i", throws: true
        };

    tcase[4] cases = [caseOne, caseTwo, caseThree, caseFour];

    testEmissionState!(state_template!(char[], char).isLparen, char[], char)(cases);
}

unittest
{
    writeln("Running test cases for isOperator");

    tcase caseOne = {
        input: cast(char[]) " 10", throws: false, emits: true, emits_class: "operator",
        prefilled_char_buffer: cast(char[]) "+", char_buffer_expected: cast(char[]) "+"
        };

    tcase[1] cases = [caseOne];

    testEmissionState!(state_template!(char[], char).isOperator, char[], char)(cases);
}
