module ceres.lexer.utils;


version (unittest)
{
    import blerp.blerp;

    static this()
    {
        runTests!(__MODULE__);
    }
}

import blerp.blerp : BlerpTest;

bool isNewLine(char character)
{
    import std.uni : lineSep, paraSep, nelSep;

    if (character == lineSep || character == paraSep || character == nelSep || character == 0x0a || character == 0x00)
        return true;
    else if (character == '\n' || character == '\r')
        return true;
    else
        return false;
}

@BlerpTest("test_isNewLine") unittest
{
    assert(isNewLine('|') == false, "| is being counted as a newline");
    assert(isNewLine('\n') == true, "\\n is not being counted as a new line");
    assert(isNewLine(0x0a) == true, "0x0a is not being counted as a new line");
}
