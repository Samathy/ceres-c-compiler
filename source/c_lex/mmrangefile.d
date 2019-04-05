module c_lex.mmrangefile;

import std.range;

/// Memory Mapped file as a range.
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
    }

    size_t length()
    {
        return this.f.length();
    }

    string filename;

    private
    {
        MmFile f;

        int iterator;

    }
}

unittest
{
    import std.stdio;

    auto f = new mmrangefile("resources/mmrangefile.test");

    assert(f.front() == 't');

    for (auto i = 0; i < 5; i++) //5 to include newline
    {
        f.popFront();
    }

    string oneHundred;
    foreach (c; f)
    {
        oneHundred = oneHundred ~ c;
    }

    assert(f.empty());

    assert(oneHundred == "100\n");
}
