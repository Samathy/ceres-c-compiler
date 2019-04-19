module c_lex.lexer;

version (unittest)
{
    import std.stdio : writeln;
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

template lexer(Range, RangeChar)
{
    class lexer
    {
        import std.conv : to;
        import std.uni : isAlpha;

        import c_lex.mmrangefile;
        import c_lex.token;
        import c_lex.location : loc;
        import c_lex.mmrangefile;

        this(Range f)
        {
            this.f = f;
            this.list = new token_list();
        }

        void scan()
        {
            this.current_state = new start!(Range, char)(this.f, delegate(token t) {
                list.add(t);
            });

            while (!this.f.empty())
            {
                current_state = current_state();
                this.f = current_state.f;
            }

        }

        token_list get_token_list()
        {
            return this.list;
        }

        private
        {
            Range f;

            token_list list;

            state!(Range, RangeChar) startState;

            state!(Range, RangeChar) current_state;

            int line_no;
            int column_no;
        }

    }
}

unittest
{
    tcase caseOne = {input:
    cast(char[]) "if", emitted_token_count : 1};
    tcase caseTwo = {input:
    cast(char[]) "10 0xDEADBEEF", emitted_token_count : 2};
    tcase caseThree = {
    input:
        cast(char[]) "001919, if, 0x19 ", emitted_token_count : 2};
        tcase caseFour = {
        input:
            cast(char[]) "0x19 if 0x1010 10 033", emitted_token_count : 5
    };

    tcase[2] testcases = [caseOne, caseTwo];

    testLexer!(char[], char)(testcases);
}

class token_list
{
    //TODO operator overloading to make this behave like an array too.

    import c_lex.token;

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

template state(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
{

    class state
    {
        import c_lex.token;

        this(Range f, void delegate(token t) emission_function)
        {
            this.f = f;
            this.emission_function = emission_function;
        }

        this()
        {
        };

        state opCall()
        {
            return new state(this.f, this.emission_function);
        }

        /// Overridable. Emit a token.
        void emit(token t)
        {
            this.emitted = true;
            this.emission_function(t);
        }

        final buffer_char(RangeChar c)
        {
            this.character_buffer ~= c;
        }

        final state ignore()
        {
            this.f.popFront();
            return this;
        }

        private
        {
            Range f;
            RangeChar[] character_buffer;
            bool emitted = false;
            void delegate(token t) emission_function;
        }
    }
}

template start(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
{
    class start : state!(Range, RangeChar)
    {
        import std.conv : to;
        import std.uni : isAlpha, isNumber, isWhite;
        import c_lex.token;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state!(Range, RangeChar) opCall()
        {

            RangeChar c = this.f.front();

            //If its a normal character
            if (isAlpha(c))
            {
                switch (c) //Check for the first character of each keyword.
                {
                    //TODO Can we generate this switch statement from a list of keywords?
                case 'i':
                    this.f.popFront();
                    auto next_state = new isIf!(Range, RangeChar)(f, this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                default:
                    auto next_state = new isIdentifier!(Range, RangeChar)(f, this.emission_function);
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
                    auto next_state = new isHexOrOct!(Range, RangeChar)(f, this.emission_function);
                    next_state.buffer_char(c);
                    return next_state;
                case '1': .. case '9':
                    auto next_state = new isInteger!(Range,
                            RangeChar)(f, this.emission_function);
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

            throw new stateException("Unexpected character");
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

        tcase[7] cases = [caseOne, caseTwo, caseThree, caseFour, caseFive, caseSix, caseSeven];

        testIntermediateState!(start!(char[], char), char[], char)(cases);
    }

    template isIf(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
    {
        class isIf : state!(Range, RangeChar)
        {
            import std.uni : isAlpha, isWhite, isPunctuation;
            import std.range.primitives : back;
            import c_lex.token;
            import c_lex.location;

            this(Range f, void delegate(token t) emission_function)
            {
                super(f, emission_function);
            }

            override state!(Range, RangeChar) opCall()
            {
                RangeChar c = this.f.front();

                if (this.character_buffer.back() == 'i' && c == 'f')
                {
                    this.character_buffer ~= c;
                    this.f.popFront();

                    if (!this.f.empty())
                    {
                        c = this.f.front();
                    }
                    else
                    {
                        loc l;
                        this.emit(new IF(l));
                        return new start!(Range, RangeChar)(this.f, this.emission_function);
                    }

                    if (isWhite(c) || isPunctuation(c))
                    {
                        loc l;
                        this.emit(new IF(l));
                        return new start!(Range, RangeChar)(this.f, this.emission_function);
                    }
                    else
                    {
                        this.f.popFront();
                        auto new_state = new isIdentifier!(Range, RangeChar)(this.f,
                                this.emission_function);
                        new_state.character_buffer = this.character_buffer.dup();
                        return new_state;
                    }
                }
                //Do we just have another character?

                else if (isAlpha(c))
                {
                    this.f.popFront();
                    auto new_state = new isIdentifier!(Range, RangeChar)(this.f,
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

        testKeywordEmissionState!(isIf!(char[], char), char[], char)(cases);
    }

    template isIdentifier(Range, RangeChar)
            if (isInputRange!Range && isSomeChar!RangeChar)
    {
        class isIdentifier : state!(Range, RangeChar)
        {
            import std.uni : isAlpha, isWhite, isPunctuation;
            import c_lex.token;
            import c_lex.location;

            this(Range f, void delegate(token t) emission_function)
            {
                super(f, emission_function);
            }

            // An 'I' and an F has been detected
            override state!(Range, RangeChar) opCall()
            {
                auto c = this.f.front();

                while (!f.empty())
                {
                    c = this.f.front();

                    if (isAlpha(c))
                    {
                        this.character_buffer ~= c;
                        this.f.popFront();
                    }
                    else if (isWhite(c))
                    {
                        loc l;
                        //Don't popfront, let the start state handle that whitespace
                        this.emit(new id(l, cast(immutable char[]) this.character_buffer));
                        break;
                    }
                    else if (isPunctuation(c))
                    {
                        loc l;
                        //Don't popfront, let the start state handle that punctuation
                        this.emit(new punctuator(l, new string(c)));
                        break;
                    }
                    else
                    {
                        throw new stateException("Unexpected character");
                    }
                }

                return new start!(Range, RangeChar)(this.f, this.emission_function);

            }

        }
    }

    unittest
    {

        import c_lex.token : classInfoNameToPlainName;

        tcase caseOne = {cast(char[]) "THING ", cast(char[]) "THING", false, true
    };
    tcase caseTwo = {cast(char[]) "THING\n", cast(char[]) "THING", false, true};
    tcase caseThree = {cast(char[]) " THING", cast(char[]) "", false, true};

    tcase[3] cases = [caseOne, caseTwo, caseThree];

    testEmissionState!(isIdentifier!(char[], char), char[], char)(cases);
}

template isHexOrOct(Range, RangeChar)
        if (isInputRange!Range && isSomeChar!RangeChar)
{
    class isHexOrOct : state!(Range, RangeChar)
    {
        import c_lex.token;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state!(Range, RangeChar) opCall()
        {
            RangeChar c = this.f.front();

            switch (c)
            {
            case 'x':
                this.f.popFront();
                this.buffer_char(c);
                auto new_state = new isHex!(Range, RangeChar)(this.f, this.emission_function);
                new_state.character_buffer = this.character_buffer.dup();
                return new_state;
            case '0': .. case '7':
                this.f.popFront();
                this.buffer_char(c);
                auto new_state = new isOct!(Range, RangeChar)(this.f, this.emission_function);
                new_state.character_buffer = this.character_buffer.dup();
                return new_state;
            default:
                throw new stateException("Invalid digit in hex or octal constant"); //TODO add the character to this error.
            }
        }
    }
}

unittest
{
    import c_lex.token : classInfoNameToPlainName; //ClassInfo.name is the same form as TypeInfo.name

    tcase caseOne = {cast(char[]) "x12", cast(char[]) "isHex", false, true};
    tcase caseTwo = {cast(char[]) "034", cast(char[]) "isOct", false, true};
    tcase caseThree = {cast(char[]) "9", cast(char[]) "isOct", true, false};

    tcase[3] cases = [caseOne, caseTwo, caseThree];

    testIntermediateState!(isHexOrOct!(char[], char), char[], char)(cases);

}

template isHex(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
{
    class isHex : state!(Range, RangeChar)
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.range.primitives : back;
        import std.stdio;
        import c_lex.token;
        import c_lex.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state!(Range, RangeChar) opCall()
        {
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
                loc l;
                this.emit(new hexInteger(l, cast(immutable RangeChar[]) this.character_buffer));
            }
            else
            {
                throw new stateException("Incomplete Hexadecimal character constant");
            }

            return new start!(Range, RangeChar)(this.f, this.emission_function);
        }

        private
        {
            import std.algorithm : canFind;

            bool isHexLetter(RangeChar c)
            {
                return canFind(['a', 'b', 'c', 'd', 'e', 'f', 'A', 'B', 'C', 'D', 'E', 'F'], c);
            }

        }

    }
}

unittest
{

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

    testEmissionState!(isHex!(char[], char), char[], char)(cases);
}

template isOct(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
{
    class isOct : state!(Range, RangeChar)
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.algorithm : canFind;
        import c_lex.token;
        import c_lex.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state!(Range, RangeChar) opCall()
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
            this.emit(new octInteger(l, cast(immutable RangeChar[]) this.character_buffer));

            return new start!(Range, RangeChar)(this.f, this.emission_function);
        }
    }
}

unittest
{

    tcase case1 = {cast(char[]) "1236654", cast(char[]) "1236654", false, true};
    tcase case2 = {cast(char[]) "00665  ", cast(char[]) "00665", false, true};
    tcase case3 = {cast(char[]) "0;0665  ", cast(char[]) "0", false, true};
    tcase case4 = {cast(char[]) "0x10", cast(char[]) "0", true, false};
    tcase case5 = {cast(char[]) "5742227", cast(char[]) "02227", true, false};
    tcase case6 = {cast(char[]) "0689993", cast(char[]) "0689993", true, false};

    tcase[6] cases = [case1, case2, case3, case4, case5, case6];

    testEmissionState!(isOct!(char[], char), char[], char)(cases);
}

template isInteger(Range, RangeChar) if (isInputRange!Range && isSomeChar!RangeChar)
{
    class isInteger : state!(Range, RangeChar)
    {
        import std.uni : isNumber, isWhite, isPunctuation;
        import std.stdio;
        import c_lex.token;
        import c_lex.location;

        this(Range f, void delegate(token t) emission_function)
        {
            super(f, emission_function);
        }

        override state!(Range, RangeChar) opCall()
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
                    throw new stateException("Unexpected character. Badly formed integer constant");
                }

                this.f.popFront();
            }

            loc l;
            this.emit(new integer(l, cast(immutable RangeChar[]) this.character_buffer));

            return new start!(Range, RangeChar)(this.f, this.emission_function);
        }
    }
}

unittest
{

    tcase case1 = {cast(char[]) "123455", cast(char[]) "123455", false, true};
    tcase case2 = {cast(char[]) "9283  ", cast(char[]) "9283", false, true};
    tcase case3 = {cast(char[]) "92;83  ", cast(char[]) "92", false, true};
    tcase case4 = {cast(char[]) "0x10", cast(char[]) "0x10", true, false};
    tcase case5 = {cast(char[]) "02227", cast(char[]) "02227", true, false};

    tcase[5] cases = [case1, case2, case3, case4, case5];

    testEmissionState!(isInteger!(char[], char), char[], char)(cases);
}

version (unittest)
{
    /* Container for test parameters */
    //TODO This should be better. Currently we rely on initialiser list
    // ordering to fill these in, which is silly and we should do keyword 
    //initiliaseation instead.
    //TODO add useful messages to the asserts here.
    struct tcase
    {
        char[] input = cast(char[]) "";
        char[] char_buffer_expected = cast(char[]) "";
        bool throws = false;
        bool emits = false;
        string emits_class = "";
        char[] prefilled_char_buffer = cast(char[]) "";
        int emitted_token_count = 0;
        token_list tokens = new token_list();
    }

    template testEmissionState(testcaseState, Range, RangeChar)
    {
        /* Runs a set of testcases aginst a given emitting state ( as opposed to an intermediary state ).
         * Emitting states are 'final' states.
         */
        bool testEmissionState(tcase[] cases)
        {
            import std.algorithm : equal;
            import std.stdio;

            foreach (testcase; cases)
            {
                auto I = new testcaseState!(Range, RangeChar)(testcase.input, (token) {
                    return;
                });

                try
                {
                    auto opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, "Test case threw: " ~ e.msg);
                }

                if (!testcase.throws)
                {
                    assert(I.emitted == testcase.emits, "Testcase did not emit");
                    assert(equal(testcase.char_buffer_expected, I.character_buffer),
                            "Test case character buffers did not match");
                }

            }

            return true;
        }
    }

    template testIntermediateState(testcaseState, Range, RangeChar)
    {
        /* Runs a set of testcases against a given non-emitting state
         * Non-emitting states return a new state object that we care
         * about, rather the emitting.
         */
        bool testIntermediateState(tcase[] cases)
        {
            import c_lex.token : classInfoNameToPlainName, token;

            foreach (testcase; cases)
            {
                auto I = new testcaseState!(Range, RangeChar)(testcase.input, (token t) {
                    return;
                });
                state!(Range, RangeChar) opCallRet;

                try
                {
                    opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, "Test case threw: " ~ e.msg);
                    return false;
                }

                //TODO should use 'emits_class' instead of re-using char_buffer_expected.
                assert(classInfoNameToPlainName(typeid(opCallRet)
                        .name) == testcase.char_buffer_expected);
            }

            return true;
        }
    }

    template testKeywordEmissionState(testcaseState, Range, RangeChar)
    {
        /* Runs a set of test cases against a given state which 
         * analyzes a keyword. These such states often require their character
         * buffer to have pre-existing characters.
         */
        bool testKeywordEmissionState(tcase[] cases)
        {
            import std.algorithm : equal;
            import c_lex.token : classInfoNameToPlainName;

            foreach (testcase; cases)
            {

                auto I = new testcaseState!(Range, RangeChar)(testcase.input, (token) {
                    return;
                });
                I.character_buffer = testcase.prefilled_char_buffer;

                state!(Range, RangeChar) opCallRet;

                try
                {
                    opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, "Testcase threw: " ~ e.msg);
                }

                if (!testcase.throws)
                {
                    assert(I.emitted == testcase.emits, "Test case did not emit");
                    assert(equal(testcase.char_buffer_expected, I.character_buffer),
                            "Testcase character buffers do not match");
                    assert(classInfoNameToPlainName(typeid(opCallRet).name) == testcase.emits_class);
                }
            }
            return true;
        }
    }

    template testLexer(Range, RangeChar)
    {

        bool testLexer(tcase[] cases)
        {
            import std.algorithm : equal;

            import c_lex.token : classInfoNameToPlainName, token;

            foreach (testcase; cases)
            {
                auto L = new lexer!(Range, RangeChar)(testcase.input);

                try
                {
                    L.scan();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, "Lexer testcase threw: " ~ e.msg);
                }

                if (!testcase.throws)
                {
                    assert(L.get_token_list().length() == testcase.emitted_token_count,
                            "Emitted token count is not equal the the expected count");
                }

                //TODO add assert testing the emitted token list is equal to the expected one.

            }
            return true;
        }
    }
}
