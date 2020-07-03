module ceres.parser.parser;

import ceres.lexer.token;
import ceres.lexer.lexer : token_list;

alias tokenID = ceres.lexer.token.ID;

class parser
{

    this(token_list tokens)
    {
        this.tokens = tokens;

    }

    void parse()
    {
        while (!this.tokens.empty())
        {

            /* switch/case statements can only operate on strings or integers.
             * So we use the typenames to match tokens.
             */
            switch (this.tokens.front().classinfo.name)
            {
            case "ceres.lexer.token." ~ tokenID.stringof:
                {
                    this.primary_expression();
                    continue;
                }
            default:
                {
                    throw new Exception("Token could not be handled"); //TODO ParserException
                }
            }

        }

        return;
    }

    private
    {
        token_list tokens;
        ast tree;

        void primary_expression()
        {
            this.tree.add_token(this.tokens.front());
            this.tokens.popFront();
            return;
        }
    }

}

class ast
{

    import std.container : DList;

    this()
    {
    }

    void add_token(token t, token parent = null)
    {
    }

    private
    {
        DList!(token) tree;
    }

}
