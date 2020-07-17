module ceres.parser.parser;

import ceres.lexer.token;
import ceres.lexer.lexer : token_list;
import ceres.parser.utils : AST;

import std.stdio : writeln;
import std.format : format;

version (unittest)
{
    import blerp.blerp;
    import std.stdio : writeln;

    static this()
    {
        import core.runtime;

        Runtime.moduleUnitTester = { return true; };
        runTests!(__MODULE__);
    }
}

/** Prefix all the token classnames with 'token'.
  Make it a bit more clear that we're dealing with a token type
  **/
alias tokenID = ceres.lexer.token.ID;
alias tokenPlusPlus = ceres.lexer.token.plusplus;
alias tokenMinusMinus = ceres.lexer.token.minusminus;
alias tokenSIZEOF = ceres.lexer.token.SIZEOF;
alias tokenLPAREN = ceres.lexer.token.lparen;
alias tokenRPAREN = ceres.lexer.token.rparen;
alias tokenUnaryOperator = ceres.lexer.token.unary_operator;
alias tokenINT = ceres.lexer.token.INT;

string prefix_token_module(string tokenname)
{
    return "ceres.lexer.token." ~ tokenname;
}

void error(string msg)
{
    writeln("ERROR: " ~ msg);
}

void warn(string msg)
{
    writeln("WARN: " ~ msg);
}

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
            //Add root tree node
            this.tree.add_leaf(new unary_expression(this.tokens, this.tree));
        }

        return;
    }

    private
    {
        token_list tokens;
        auto tree = new AST!(node).tree();
    }

}

/** 
  A node of the ast.
*/
abstract class node
{

    this(token_list tokens, AST!(node).tree tree)
    {
        this.tokens = tokens;
        this.tree = tree;
    }

    bool expect(string tokenname)
    {
        return tokenname == this.tokens.front().classinfo.name;
    }

    bool expect_and_eat(string tokenname)
    {
        if (expect(tokenname))
        {
            this.tokens.popFront();
            return true;
        }
        return false;
    }

    void eat()
    {
        this.tokens.popFront();
    }

    bool expect_eat_add(string tokenname)
    {
        if (this.expect(tokenname))
        {
            if (this.tree.empty()) //If we're adding the root node
            {
                this.tree.add_leaf(new token_node(this.tokens, this.tree, this.tokens.front()));
            }
            else if (this.tree.front().parent is null) //if we're adding a child to the root node
            {
                this.tree.add_leaf(new token_node(this.tokens, this.tree,
                        this.tokens.front()), this.tree.front());
            }
            else //If we're adding a child of any other node
            {

                this.tree.add_leaf(new token_node(this.tokens, this.tree,
                        this.tokens.front()), this.tree.front().parent);
            }
            this.eat();
            return true;
        }
        else
        {
            error(format("Expected %s found %s", tokenname, this.tokens.front().toString()));
            return false;
        }
    }

    /** This is only used in the class token_node, 
        but because the tree container generic on the node class, the compiler
        doesnt know that this data exists for subtypes where it exists.
        */
    public token t;

    private
    {
        token_list tokens;
        AST!(node).tree tree;
    }

}

/** An external node of the AST!(node).tree ( a leaf )
  Has 0 children, but this isnt enforced.
  */
abstract class enode : node
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
    }
}

/** An internal node of the ast.
    Has children, but this isnt inforced.
    */
abstract class inode : node
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
    }

}

/** Contains a token string,
  rather than expression type.
  */
class token_node : enode
{
    this(token_list tokens, AST!(node).tree tree, token t)
    {
        super(tokens, tree);
        this.t = t;
    }
}

/** 
  Placeholder node for using when 
  we havent implemented parsing that far yet
  */
class void_node : node
{
    this(token_list tokens, AST!(node).tree tree, token t = null)
    {
        super(tokens, tree);
    }

    public token t;
}

class unary_expression : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);

        tree.add_leaf(this, this.tree.front());

        token t = this.tokens.front();

        switch (t.classinfo.name)
        {
        case prefix_token_module(tokenPlusPlus.stringof):
            {
                this.expect_eat_add(prefix_token_module(tokenPlusPlus.stringof));
                this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
                break;
            }
        case prefix_token_module(tokenMinusMinus.stringof):
            {
                this.expect_eat_add(tokenMinusMinus.stringof);
                this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
                break;
            }
        case prefix_token_module(tokenSIZEOF.stringof):
            {
                this.expect_eat_add(prefix_token_module(tokenSIZEOF.stringof));
                if (this.expect_eat_add(prefix_token_module(tokenLPAREN.stringof)))
                {
                    this.tree.add_leaf(new type_name(tokens, tree), this.tree.front);
                    this.expect_eat_add(prefix_token_module(tokenRPAREN.stringof));
                }
                else
                    this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
                break;
            }
        case prefix_token_module(tokenUnaryOperator.stringof):
            {
                this.expect_eat_add(tokenUnaryOperator.stringof);
                this.tree.add_leaf(new cast_expression(tokens, tree), this.tree.front);
                break;
            }
        default:
            {
                this.tree.add_leaf(new postfix_expression(tokens, tree), this.tree.front);
            }
        }

        return;
    }
}

class type_name : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
        error(format("%s production not implemented", this.classinfo.name));
        this.eat();
        this.tree.add_leaf(new void_node(tokens, tree), this.tree.front);
    }
}

class postfix_expression : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
        error(format("%s production not implemented", this.classinfo.name));
        this.eat();
        this.tree.add_leaf(new void_node(tokens, tree), this.tree.front);
    }
}

class cast_expression : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
        error(format("%s not production not implemented", __FUNCTION__));
        this.eat();
        this.tree.add_leaf(new void_node(tokens, tree), this.tree.front);
    }
}

@BlerpTest("test_prefix_token_module") unittest
{
    assert(prefix_token_module(tokenMinusMinus.stringof) == "ceres.lexer.token.minusminus");
}

@BlerpTest("test_node_expect_eat_add") unittest
{

    class non_abstract_node : node
    {
        this(token_list tokens, AST!(node).tree tree)
        {
            super(tokens, tree);
        }
    }

    import ceres.lexer.location : loc;

    auto tokens = new token_list();
    auto l = loc();

    tokens.add(new tokenPlusPlus(l, "++"));
    tokens.add(new tokenMinusMinus(l, "--"));
    tokens.add(new tokenLPAREN(l, "("));
    tokens.add(new tokenRPAREN(l, ")"));
    tokens.add(new tokenPlusPlus(l, "++"));
    tokens.add(new tokenSIZEOF(l));

    auto tree = new AST!(node).tree();
    tree.add_leaf(new void_node(tokens, tree));

    auto node = new non_abstract_node(tokens, tree);

    assert(node.expect(prefix_token_module(tokenPlusPlus.stringof)), "node.expect returned false");

    assert(node.expect_and_eat(prefix_token_module(tokenPlusPlus.stringof)),
            "Failed to expect and eat tokenPlusPlus");
    assert(tokens.front().toString() == prefix_token_module(tokenMinusMinus.stringof),
            format("Front of token list incorrect. Expected %s got %s",
                tokenMinusMinus.stringof, tokens.front().toString()));

    assert(node.expect_eat_add(prefix_token_module(tokenMinusMinus.stringof)),
            "Failed to expect_eat_add tokenMinusMinus");
    assert(tokens.front().classinfo.name == prefix_token_module(tokenLPAREN.stringof),
            format("Front of token list incorrect. Expected %s got %s",
                tokenLPAREN.stringof, tokens.front().classinfo.name));

    assert(tree.root.children[0].data.t.classinfo.name == prefix_token_module(tokenMinusMinus.stringof),
            format("Expected child of root tree node to be %s, got %s",
                prefix_token_module(tokenMinusMinus.stringof),
                tree.root.children[0].data.t.classinfo.name));

    assert(!tree.empty(), "Tree doesnt contain any nodes");
    assert(tree.length == 2, "Number of nodes in the tree is not as expected");
}

@BlerpTest("test_unary_expression") unittest
{
    /* TODO
       Currently this only tests that unary_expression 
       parses "sizeof ( type-name )" properly
       */
    import ceres.lexer.location : loc;

    auto tokens = new token_list();
    auto l = loc();
    auto tree = new AST!(node).tree();
    tree.add_leaf(new void_node(tokens, tree));

    tokens.add(new tokenSIZEOF(l));
    tokens.add(new tokenLPAREN(l, "("));
    tokens.add(new tokenINT(l));
    tokens.add(new tokenRPAREN(l, ")"));

    string[] children = [
        prefix_token_module(tokenSIZEOF.stringof),
        prefix_token_module(tokenRPAREN.stringof), "ceres.parser.parser.type_name",
        prefix_token_module(tokenLPAREN.stringof),
    ];

    tree.add_leaf(new unary_expression(tokens, tree), tree.front());

    assert(
            tree.root.children[0].data.classinfo.name == "ceres.parser.parser."
            ~ unary_expression.stringof);
    assert(
            tree.root.children[0].data.classinfo.name == "ceres.parser.parser."
            ~ unary_expression.stringof);

    assert(tree.children_match(children, tree.root.children[0]),
            "Some of the node's children don't match");

}
