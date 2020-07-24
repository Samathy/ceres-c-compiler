module ceres.parser.parser;

import ceres.lexer.token;
import ceres.lexer.lexer : token_list;
import ceres.parser.utils : AST, isChildOf, isTypeOf;

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

alias tokenID = ceres.lexer.token.ID;
alias tokenPlusPlus = ceres.lexer.token.plusplus;
alias tokenMinusMinus = ceres.lexer.token.minusminus;
alias tokenSIZEOF = ceres.lexer.token.SIZEOF;
alias tokenLPAREN = ceres.lexer.token.lparen;
alias tokenRPAREN = ceres.lexer.token.rparen;
alias tokenUnaryOperator = ceres.lexer.token.unary_operator;
alias tokenINT = ceres.lexer.token.INT;

void error(string msg)
{
    writeln("ERROR: " ~ msg);
}

void warn(string msg)
{
    writeln("WARN: " ~ msg);
}

/** The main parser class 
  */
class parser
{

    this(token_list tokens)
    {
        this.tokens = tokens;

    }

    /** Main parse method.
      Works through the token list until there are no more tokens.
      */
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

    /** Return true if the front token of the token list
      is the same as the given expected token.
      */
    template expect(expected)
    {
        bool expect()
        {
            return this.tokens.front().isChildOf!(expected);
        }
    }

    /** Return true if the front token of the token list
      is the same as the given expected token.
      Also eat the front character from the tokenlist.
      */
    template expect_and_eat(expected)
    {
        bool expect_and_eat()
        {
            if (expect!(expected))
            {
                this.tokens.popFront();
                return true;
            }
            return false;
        }
    }

    /** Pop front character from the token list
      */
    void eat()
    {
        this.tokens.popFront();
    }

    /** Return true if the front token of the token list
      is the same as the given expected token.
      Also eat the front character from the tokenlist.
      Also add the front token to the tree as a child of the last node.
      */
    template expect_eat_add(expected)
    {
        bool expect_eat_add()
        {
            if (this.expect!(expected))
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
                error(format("Expected %s found %s", expected.classinfo.name,
                        this.tokens.front().toString()));
                return false;
            }
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

/** parsing node */

class unary_expression : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);

        tree.add_leaf(this, this.tree.front());

        token t = this.tokens.front();

        if (t.isChildOf!(tokenPlusPlus))
        {
            this.expect_eat_add!(tokenPlusPlus);
            this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
        }
        else if (t.isChildOf!(tokenMinusMinus))
        {
            this.expect_eat_add!(tokenMinusMinus);
            this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
        }
        else if (t.isChildOf!(tokenSIZEOF))
        {
            this.expect_eat_add!(tokenSIZEOF);
            if (this.expect_eat_add!(tokenLPAREN))
            {
                this.tree.add_leaf(new type_name(tokens, tree), this.tree.front);
                this.expect_eat_add!(tokenRPAREN);
            }
            else
                this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
        }
        else if (t.isChildOf!(tokenUnaryOperator))
        {
            this.expect_eat_add!(tokenUnaryOperator);
            this.tree.add_leaf(new cast_expression(tokens, tree), this.tree.front);
        }
        else
        {
            this.tree.add_leaf(new postfix_expression(tokens, tree), this.tree.front);
        }

        return;
    }
}

/** typename expression */
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

/** postfix expression */
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

/** case expression */
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

    assert(node.expect!(tokenPlusPlus), "node.expect returned false");

    assert(node.expect_and_eat!(tokenPlusPlus), "Failed to expect and eat tokenPlusPlus");

    assert(tokens.front().isTypeOf!(tokenMinusMinus), format("Front of token list incorrect. Expected %s got %s",
            tokenMinusMinus.stringof, tokens.front().classinfo.name));

    assert(node.expect_eat_add!(tokenMinusMinus)(), "Failed to expect_eat_add tokenMinusMinus");

    assert(tokens.front().isTypeOf!(tokenLPAREN), format("Front of token list incorrect. Expected %s got %s",
            tokenLPAREN.stringof, tokens.front().classinfo.name));

    assert(tree.root.children[0].data.t.isTypeOf!(tokenMinusMinus),
            format("Expected child of root tree node to be %s, got %s",
                tokenMinusMinus.stringof, tree.root.children[0].data.t.classinfo.name));

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

    /*
       TODO Checking the list of children still depends on 
       checking the typename strings against a list of expected typename
       strings.
       I havent figured out how to make a list of _types_ and check runtime
       types against that list yet

    string[] children = [
        prefix_token_module(tokenSIZEOF.stringof),
        prefix_token_module(tokenRPAREN.stringof), "ceres.parser.parser.type_name",
        prefix_token_module(tokenLPAREN.stringof),
    ];
    */

    tree.add_leaf(new unary_expression(tokens, tree), tree.front());

    assert(
            tree.root.children[0].data.classinfo.name == "ceres.parser.parser."
            ~ unary_expression.stringof);
    assert(
            tree.root.children[0].data.classinfo.name == "ceres.parser.parser."
            ~ unary_expression.stringof);

    /*
    assert(tree.children_match(children, tree.root.children[0]),
            "Some of the node's children don't match");
    */
}
