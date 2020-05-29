/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module ceres.lexer.lexer_test_utils;

import std.traits : BaseTypeTuple;
import std.meta : AliasSeq;

import ceres.lexer.lexer;

version (unittest)
{
    /* Container for test parameters */
    //TODO This should be better. Currently we rely on initialiser list
    // ordering to fill these in, which is silly and we should do keyword 
    //initiliaseation instead.
    //TODO add useful messages to the asserts here.
    struct tcase
    {
        char[] input = cast(char[]) ""; //The input string
        char[] char_buffer_expected = cast(char[]) ""; //What should be in the character buffer on return?
        bool throws = false;
        bool emits = false; //Emits a token?
        string emits_class = ""; //Which token?
        char[] prefilled_char_buffer = cast(char[]) ""; //Prefill the input char buffer
        int emitted_token_count = 0; //How many tokens are emitted ( This isnt used )
        string returns_class = ""; 
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
            import std.format: format;
            import ceres.lexer.token : classInfoNameToPlainName, token;

            foreach (size_t i, testcase; cases)
            {
                token emitted;
                auto I = new testcaseState(testcase.input, delegate(token t) { emitted = t; });

                I.character_buffer = testcase.prefilled_char_buffer;
                
                state_template!(Range, RangeChar).state opCallRet;

                try
                {
                    opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, "Test case threw: " ~ e.msg);
                }

                if (!testcase.throws)
                {
                    if ( testcase.emits )
                    {
                        assert ( classInfoNameToPlainName(typeid(emitted).name) == testcase.emits_class, 
                                format("Test case %s should have emitted %s, actually emitted %s",
                                    i, testcase.emits_class, classInfoNameToPlainName(typeid(emitted).name)));
                    }
                    
                    assert(I.emitted == testcase.emits, format("Test case %s did not emit", i));
                    //Overloading char_buffer_expected
                
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
            import ceres.lexer.token : classInfoNameToPlainName, token;
            import std.format: format;

            foreach (size_t i, testcase; cases)
            {
                auto I = new testcaseState(testcase.input, (token t) { return; });
                I.character_buffer = testcase.prefilled_char_buffer;
                state_template!(Range, RangeChar).state opCallRet;

                try
                {
                    opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, format("Test case %s threw: %s", i, e.msg));
                    return false;
                }

                assert(classInfoNameToPlainName(typeid(opCallRet)
                        .name) == testcase.returns_class, 
                        format("Test case %s should return class %s actually returned %s", 
                        i, testcase.returns_class, classInfoNameToPlainName(typeid(opCallRet).name)));
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
            import std.format: format;
            import ceres.lexer.token : classInfoNameToPlainName, token;

            foreach (size_t i, testcase; cases)
            {
                
                token emitted;

                auto I = new testcaseState(testcase.input, delegate(token t) { emitted = t; });
                I.character_buffer = testcase.prefilled_char_buffer;

                state_template!(Range, RangeChar).state opCallRet;

                try
                {
                    opCallRet = I();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, format("Test case %s threw: %s", i, e.msg));
                }

                if (!testcase.throws)
                {
                    if (testcase.emits)
                    {
                        assert(I.emitted == testcase.emits, format("Test case %s did not emit", i));
                        assert ( classInfoNameToPlainName(typeid(emitted).name) == testcase.emits_class, 
                                format("Test case %s Should have emitted class %s, actually emitted %s",i, testcase.emits_class, classInfoNameToPlainName(typeid(emitted).name)));
                    }
                    assert(equal(testcase.char_buffer_expected, I.character_buffer),
                            format("Test case %s character buffers do not match", i));
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
            import std.format:format;

            import ceres.lexer.token : classInfoNameToPlainName, token;

            foreach (size_t i, testcase; cases)
            {
                auto L = new lexer!(Range, RangeChar)(testcase.input);

                try
                {
                    L.scan();
                }
                catch (Exception e)
                {
                    assert(testcase.throws, format("Test case %s threw: %s", i, e.msg));
                }

                if (!testcase.throws)
                {
                    assert(L.get_token_list().length() == testcase.emitted_token_count,
                            format("Test case %s should have emitted %s tokens, actually emitted %s tokens: %s", i, testcase.emitted_token_count, L.get_token_list().length(), L.get_token_list()));
                }

                //TODO add assert testing the emitted token list is equal to the expected one.

            }
            return true;
        }
    }
}
