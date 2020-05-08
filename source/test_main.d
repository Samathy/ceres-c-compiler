import c_lex.lexer : lexer, stateException;
import c_lex.mmrangefile : mmrangefile;
import std.stdio : writeln;

int main()
{

    auto source = new mmrangefile("resources/source.c");

    auto l = new lexer!(mmrangefile, char)(source);

    try
    {
        l.scan();
    }
    catch (stateException e)
    {
        writeln(e.msg);
    }

    writeln(l.get_token_list());

    return 0;

}
