import ceres.lexer.lexer : lexer, stateException;
import ceres.lexer.mmrangefile : mmrangefile;
import std.stdio : writeln, File;

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

    auto f = File("lexer_state_graph.dot", "w");

    f.writeln(l.get_state_graph_dot());

    return 0;

}
