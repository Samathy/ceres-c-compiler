module ceres.parser.parser;

import ceres.lexer.token;
import ceres.lexer.lexer : token_list;
import ceres.parser.utils : AST, isTypeOf;

import std.stdio : writeln;
import std.format : format;

version (unittest)
{
    import std.stdio : writeln;

}


alias tokenID = ceres.lexer.token.ID;
alias tokenPlusPlus = ceres.lexer.token.plusplus;
alias tokenMinusMinus = ceres.lexer.token.minusminus;
alias tokenSIZEOF = ceres.lexer.token.SIZEOF;
alias tokenLPAREN = ceres.lexer.token.lparen;
alias tokenRPAREN = ceres.lexer.token.rparen;
alias tokenUnaryOperator = ceres.lexer.token.unary_operator;
alias tokenINT = ceres.lexer.token.INT;
alias tokenLBRACE = ceres.lexer.token.lcurly;
alias tokenRBRACE = ceres.lexer.token.rcurly;
alias tokenCOMMA = ceres.lexer.token.comma;
alias tokenSTOP = ceres.lexer.token.stop;
alias tokenLSBRACE = ceres.lexer.token.lsquare;
alias tokenRightArr = ceres.lexer.token.rightArrow;

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
            return this.tokens.front().isTypeOf!(expected);
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
        bool expect_eat_add(bool append = false)
        {
            if (this.expect!(expected))
            {
                if (this.tree.empty()) //If we're adding the root node
                {
                    this.tree.add_leaf(new token_node(this.tokens, this.tree,
                            this.tokens.front()), null, true);
                }
                else if (this.tree.length == 1) //if we're adding a child to the root node
                {
                    this.tree.add_leaf(new token_node(this.tokens, this.tree,
                            this.tokens.front()), this.tree.front(), true);
                }
                else //If we're adding a child of any other node
                {
                    this.tree.add_leaf(new token_node(this.tokens, this.tree,
                            this.tokens.front()), this.tree.front(), true);
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
        /* I hate how getting the token data from an AST leaf 
           looks like this.tree.root.children[0].data.t.
           But I don't yet know how to abstract it away to make 
           it easier.
        */

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

        /* 
           We only need this because `unary_expression` is 
           the FIRST 
        */
        tree.add_leaf(this, this.tree.front());

        token t = this.tokens.front();

        if (t.isTypeOf!(tokenPlusPlus))
        {
            this.expect_eat_add!(tokenPlusPlus);
            this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
        }
        else if (t.isTypeOf!(tokenMinusMinus))
        {
            this.expect_eat_add!(tokenMinusMinus);
            this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front);
        }
        else if (t.isTypeOf!(tokenSIZEOF))
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
        else if (t.isTypeOf!(tokenUnaryOperator))
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

        token t = this.tokens.front();

        if (t.isTypeOf!(tokenLPAREN))
        {
            this.expect_eat_add!(tokenLPAREN);
            this.tree.add_leaf(new type_name(tokens, tree), this.tree.front);
            this.expect_eat_add!(tokenRPAREN);
            this.expect_eat_add!(tokenLBRACE);
            this.tree.add_leaf(new initializer_list(tokens, tree), this.tree.front);

            if (!this.expect_eat_add!(tokenRBRACE) && this.expect_eat_add!(tokenCOMMA))
                this.expect_eat_add!(tokenRBRACE);
        }

        else
        {
            this.tree.add_leaf(new postfix_expression(tokens, tree), this.tree.front);
            if (this.expect_eat_add!(tokenLSBRACE))
                error(format("%s production not implemented", this.classinfo.name));
            else if (this.expect_eat_add!(tokenLPAREN))
                error(format("%s production not implemented", this.classinfo.name));
            else if (this.expect_eat_add!(tokenSTOP))
                this.expect_eat_add!(tokenID);
            else if (this.expect_eat_add!(tokenRightArr))
                this.expect_eat_add!(tokenID);
            else if (this.expect_eat_add!(tokenPlusPlus))
                return;
            else if (this.expect_eat_add!(tokenMinusMinus))
                return;
            else
                this.tree.add_leaf(new primary_expression(tokens, tree), this.tree.front);
        }

    }
}

/** initializer list expression */
class initializer_list : inode
{
    this(token_list tokens, AST!(node).tree tree)
    {
        super(tokens, tree);
        error(format("%s production not implemented", this.classinfo.name));
        this.eat();
        this.tree.add_leaf(new void_node(tokens, tree), this.tree.front);
    }
}

/** initializer list expression */
class primary_expression : inode
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

        token t = this.tokens.front();

        if (t.isTypeOf!(tokenLPAREN))
        {
            this.expect_eat_add!(tokenLPAREN);
            this.tree.add_leaf(new type_name(tokens, tree), this.tree.front());
            this.expect_eat_add!(tokenRPAREN);
            this.tree.add_leaf(new cast_expression(tokens, tree), this.tree.front());
        }
        else
        {
            this.tree.add_leaf(new unary_expression(tokens, tree), this.tree.front());
        }
        return;
    }
}

@("test_node_expect_eat_add") unittest
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

    assert(node.expect_eat_add!(tokenLPAREN), format("Tried to expect_eat_add %s, got %s",
            tokenLPAREN.stringof, tokens.front.classinfo.name));

    writeln(tree.get_tree_graph_dot("test_node_expected_eat_add.dot"));
    assert(tree.root.children.length == 2, "Root doesnt have enough children");
    assert(tree.root.children[1].data.t.isTypeOf!(tokenLPAREN),
            "Expected second child to be LPAREN, but it isnt");

    assert(!tree.empty(), "Tree doesnt contain any nodes");
    assert(tree.length == 3,
            format("Number of nodes in the tree is not as expected. Expected %s, got %s",
                3, tree.length));

}

@("test_unary_expression") unittest
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

    auto ue = tree.root.children[0];

    writeln(tree.get_tree_graph_dot("test_unary_expression.dot"));

    assert(ue.children[0].data.classinfo.name == "ceres.parser.parser." ~ token_node.stringof);

    /*
    assert(tree.children_match(children, tree.root.children[0]),
            "Some of the node's children don't match");
   */
}

@("test_cast_expression") unittest
{
    import ceres.lexer.location : loc;

    auto tokens = new token_list();
    auto l = loc();
    auto tree = new AST!(node).tree();
    tree.add_leaf(new void_node(tokens, tree));

    tokens.add(new tokenSIZEOF(l));
    tokens.add(new tokenLPAREN(l, "("));
    tokens.add(new tokenINT(l));
    tokens.add(new tokenRPAREN(l, ")"));

    tree.add_leaf(new cast_expression(tokens, tree), tree.front());

    writeln(tree.get_tree_graph_dot());

    assert(tree.root.children[0].data.isTypeOf!(unary_expression));
    assert(false, "Finish this test");

}
