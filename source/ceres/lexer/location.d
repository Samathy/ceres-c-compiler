/**
* Copyright: 2020 Samathy Barratt
*
* Authors: Samathy Barratt
* License: BSD 3-Clause
*
* This file is part of the Ceres C compiler
*
*/
module ceres.lexer.location;

/** 
  * File location structure. 
  * Stores information about where
  * we are in the file
  */
struct loc
{
    int line_no;
    int column_no;
    string filename;
}

unittest
{
    auto l = loc(10, 10, "foo.c");

    assert(l.line_no == 10);
    assert(l.column_no == 10);
    assert(l.filename == "foo.c");

}
