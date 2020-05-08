module c_lex.lexer_test_utils;

import std.traits : BaseTypeTuple;
import std.meta : AliasSeq;

import c_lex.lexer;

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
            if (is(BaseTypeTuple!(testcaseState) == AliasSeq!(state_template!(Range,
                RangeChar).state)) || is(s == state_template!(c).state))
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
                auto I = new testcaseState(testcase.input, (token) { return; });

                I.character_buffer = testcase.prefilled_char_buffer;

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
            if (is(BaseTypeTuple!(testcaseState) == AliasSeq!(state_template!(Range,
                RangeChar).state)) || is(s == state_template!(c).state))
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
                auto I = new testcaseState(testcase.input, (token t) { return; });
                state_template!(Range, RangeChar).state opCallRet;

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
            if (is(BaseTypeTuple!(testcaseState) == AliasSeq!(state_template!(Range,
                RangeChar).state)) || is(s == state_template!(c).state))
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

                auto I = new testcaseState(testcase.input, (token) { return; });
                I.character_buffer = testcase.prefilled_char_buffer;

                state_template!(Range, RangeChar).state opCallRet;

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
