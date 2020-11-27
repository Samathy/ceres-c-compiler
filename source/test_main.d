import ceres.lexer.lexer : lexer, stateException;
import ceres.lexer.mmrangefile : mmrangefile;
import ceres.parser.parser: parser;
import std.stdio : writeln, File;

import std.getopt;


int main(string[] argv)
{
    string[] input;
    bool verbose;

    string arraySep = ",";

    auto helpInformation = getopt(
            argv,
            "input", "Input files", &input,
            "verbose", "Enable verbose output", &verbose,);


    auto source = new mmrangefile(input[0]); //Only support one input right now.

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

    auto p = new parser(l.get_token_list());
    
    p.parse();


    return 0;

}
