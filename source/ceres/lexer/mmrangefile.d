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

import ceres.lexer.location : loc;

import ceres.lexer.utils: isNewLine;

version (unittest)
{
    import blerp.blerp;

    static this()
    {
        runTests!(__MODULE__);
    }
}

import blerp.blerp : BlerpTest;

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
        return (this.iterator >= this.length());
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
        assert( this.iterator+1 <= this.length() );

        this.iterator++;

        if (isNewLine(this.f[this.iterator - 1]))
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
    import std.format: format;

    auto f = new mmrangefile("resources/mmrangefile.test");

    assert(f.front() == 't', format("Expected first character to be %s, got %s", "t", f.front()));

    for (auto i = 0; i < 5; i++) //5 to include newline
    {
        f.popFront();
    }

    assert ( f.iterator == 5 );

    assert(f.current_location.column_no == 0, format("Expected column number to be %s, got %s", 0, f.current_location.column_no));
    assert(f.current_location.line_no == 2, format("Expected line number to be %s, got %s", 1, f.current_location.line_no));

    string oneHundred;
    foreach (c; f)
    {
        oneHundred = oneHundred ~ c;
    }

    assert(f.empty());

    assert(oneHundred == "100\n");
}
