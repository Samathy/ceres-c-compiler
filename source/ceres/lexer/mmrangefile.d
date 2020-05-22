/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module ceres.lexer.mmrangefile;

import std.range;

import ceres.lexer.location: loc;

version (unittest)
{
    import blerp.blerp;
    static this()
    {
        runTests!(__MODULE__);
    }
}

import blerp.blerp: BlerpTest;

/** 
  * An input range backed by a memory-mapped file
  * This is the primary input to the lexer.
  */
class mmrangefile
{
    import std.mmfile;

    this(string filename)
    in
    {
        assert(filename != "");
    }
    body
    {
        this.filename = filename;
        this.f = new MmFile(filename);
        this.current_location.filename = filename;
    }

    @property bool empty()
    {
        return (this.iterator >= this.f.length);
    }

    char front()
    {
        return cast(char) this.f[this.iterator];
    }

    void back()
    {
        this.iterator--;
    }

    void popFront()
    {
        this.iterator++;

        if ( isNewLine(this.f[this.iterator]) )
        {
            this.current_location.line_no += 1;
            this.current_location.column_no = 0;
        }
        else
            this.current_location.column_no += 1;

    }

    size_t length()
    {
        return this.f.length();
    }

    private bool isNewLine(char character)
    {
        import std.uni: lineSep, paraSep, nelSep;
        if (character == lineSep || character == paraSep || character == nelSep)
            return true;
        else if ( character == '\n' || character == '\r' )
            return true;
        else 
            return false;
    }

    string filename;
    loc current_location;

    private
    {
        MmFile f;


        int iterator;

    }
}

@BlerpTest("test_mmrangefile") unittest
{
    import std.stdio;

    auto f = new mmrangefile("resources/mmrangefile.test");

    assert(f.front() == 't');

    for (auto i = 0; i < 5; i++) //5 to include newline
    {
        f.popFront();
    }

    assert(f.current_location.column_no == 0 );
    assert(f.current_location.line_no == 1 );

    string oneHundred;
    foreach (c; f)
    {
        oneHundred = oneHundred ~ c;
    }

    assert(f.empty());

    assert(oneHundred == "100\n");
}
