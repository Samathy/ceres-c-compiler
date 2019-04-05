module c_lex.location;

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
