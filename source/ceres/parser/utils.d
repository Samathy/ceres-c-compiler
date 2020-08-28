module ceres.parser.utils;
import std.exception;

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

/** 
  Returns true if the object's type matches the given type
  Also returns true if the given runtime object's superclass is
  the same as the given type. 
  */
template isTypeOf(base) if (is(base == class))
{
    bool isTypeOf(Object child)
    {
        return base.classinfo.isBaseOf(child.classinfo);
    }
}

@BlerpTest("test_isTypeOf_true_when_child") unittest
{
    class a
    {}
    class b: a
    {}
    auto b_obj = new b();
    assert(isTypeOf!(a)(b_obj));
}

@BlerpTest("test_isChildOf_true_when_matches") unittest
{
    class a
    {}
    class b: a
    {}

    auto b_obj = new b();
    assert(isTypeOf!(b)(b_obj));
}


/* 
 * I reckon using a Region allocator might make trees faster to use.
 * Because they're essentially linked lists, we might benefit from 
 * having all the leafs in a tree allocated in the same memory region, 
 * rather than further away leaves being further away in memory.
 * Linked lists are notoriously bad for traversal performance
 * if they get allocated just anywhere.
 * But, I dont know how much traversal we'll be doing, 
 * and swapping a different allocator is premature optimisation
 * This is especially pertinent if we basically never remove elements from the tree, 
 * or add elements between others.
 * https://dlang.org/phobos/std_experimental_allocator.html
 * https://dlang.org/phobos/std_experimental_allocator_building_blocks_region.html
 */

template AST(leaf_type)
{

    class TreeException : Exception
    {
        this(string message)
        {
            super(message);
        }
    }

    class LeafException : TreeException
    {
        this(string message)
        {
            super(message);
        }
    }

    class tree
    {
        import std.typecons : Nullable;

        this()
        {
        }

        /** TODO Returns a dot graph of the tree and it's contents */
        string get_tree_graph_dot(string filename=null)
        {
            import std.format: format;
            import std.traits: isBasicType;
            import std.string: replace;

            string node_lable(leaf node)
            {
                return format("%s_%s", node.data, &node.data).replace(".", "_");
            }

            string append_children(leaf node)
            {
                string output;

                if ( node.children.length > 0 )
                {
                    foreach(child; node.children)
                    {
                        if (child.terminal)
                            output ~= format("%s [peripheries=2]", node_lable(child));
                        output ~= format("%s -> %s; \n", node_lable(node), node_lable(child));
                    }

                    foreach(child; node.children)
                    {
                        output ~= append_children(child);
                    }
                }
                return output;
            }

            string output = "digraph AST{\n";
            output~= append_children(this.root_item);
            output~="}";

            if (filename)
            {
                import std.stdio: File;
                auto output_file = File(filename, "w");
                output_file.write(output);
            }

            return output;

        }

        /** Searches for a particular node in the tree.
          Returns Nullable!leaf.isNull if node not found, else
          returns the node
          */
        Nullable!leaf search_by_data(leaf_type to_find)
        {
            return this.recursive_search(this.root, to_find);
        }

        bool children_match(string[] children, leaf node)
        {
            foreach (size_t i, child; node.children)
            {
                if (child.classinfo.name == children[i])
                    continue;
                else
                    return false;
            }

            return true;
        }

        /** Add a new leaf to the tree. Optionally specify parent.
          * If parent is null, node considered the root.
          */
        void add_leaf(leaf_type leaf_data, leaf parent = null, bool terminal = false)
        in
        {
            import std.format : format;

            assert((parent is null && this.root_item is null) || (parent !is null
                    && this.root_item !is null),
                    format("Tried to add leaf when parent is %s and root is %s. \n"
                        ~ "Either you tried to add a root leaf when one exists "
                        ~ "or you tried to add a leaf with a parent when there is not root",
                        parent, this.root));
        }
        out
        {
            if (parent is null)
            {
                assert(this.root !is null);
                assert(this.front_item !is null);
                assert(this.length - 1 == 0);
                assert(this.root_item.data == leaf_data);

                /* If we added a terminal, dont change the front node.
                   We only need to add nodes to non-terminals
                */
                if (terminal == true)
                    assert(this.front_item.data != leaf_data);
                else
                    assert(this.front_item.data == leaf_data);
            }
            else if (parent !is null)
            {
                assert(this.root !is null);

                if (terminal)
                {
                    /*This falls apart when the data is identical.
                    e.g when using 'int' type under test
                    */
                    //assert(this.front_item.data != leaf_data);
                    {}
                }
                else
                    assert(this.front_item.data == leaf_data);
                //assert(this.root_item.parent.get_child_by_data(leaf_data).data == leaf_data);
            }
        }
        do
        {
            if (parent is null)
            {
                auto new_leaf = new leaf(leaf_data, null, terminal);
                new_leaf.is_root = true;

                this.root_item = new_leaf;

                /* Adding a terminal as a root is stupid,
                   but allowed
                */
                if (!terminal)
                    this.front_item = this.root_item;
                this.length += 1;
                return;
            }
            else if (this.root_item == parent)
            {
                auto new_leaf = new leaf(leaf_data, this.root_item, terminal);

                if (!terminal)
                    this.front_item = new_leaf;
                this.root_item.children ~= new_leaf;
                this.length += 1;
                return;
            }
            else
            {
                auto new_leaf = new leaf(leaf_data, parent, terminal);

                if(!terminal)
                    this.front_item = new_leaf;
                parent.children ~= new_leaf;
                this.length += 1;
                return;
            }
        }

        @property pure bool empty()
        {
            if (this.root_item is null)
                return true;
            else
                return false;
        }

        /** The root node of the tree */
        @property leaf root()
        {
            if (this.root_item !is null)
                return this.root_item;
            else
                throw new TreeException("Attempted to get the root of an empty tree");
        }

        /** The last-added tree leaf. This is not affected by traversing the tree
          */
        @property leaf front()
        {
            if (this.empty())
                throw new TreeException("Attempted to call front() on an empty tree object");
            else
                return this.front_item;

        }

        private Nullable!leaf recursive_search(leaf start, leaf_type to_find)
        {
            import std.array : empty;
            import std.format : format;

            if (start == to_find)
                return Nullable!leaf(start);

            leaf current_leaf = start;

            if (current_leaf.children.empty)
                return Nullable!leaf();

            //Cant get it to walk back up the tree if the recusive function throws.
            foreach (child; current_leaf.children)
            {

                if (child == to_find)
                    return Nullable!leaf(child);
                if (child.children.empty)
                    continue;

                auto ret = this.recursive_search(child, to_find);
                if (!ret.isNull)
                    return ret;
            }

            return Nullable!leaf();
        }

        public int length;

        private
        {
            leaf root_item;
            leaf front_item;
        }
    }


    /** Leaf of the tree, contains data and information about parents and children */
    class leaf
    {
        import std.algorithm: canFind;

        this(leaf_type data, leaf parent, bool terminal=false)
        {
            this.terminal = terminal;

            this.data = data;

            if (parent is null)
                this.is_root = true;

            this.parent = parent;
            return;
        }

        bool opEquals(leaf_type o)
        {
            return this.data == o;
        }

        override bool opEquals(Object o)
        {
            return this is o;
        }

        bool opEquals(size_t o)
        {
            return this.toHash() == o;
        }

        void opAssign(leaf_type data)
        {
            this.data = data;
        }

        size_t search_children_by_data(leaf_type data)
        {
            if (this.children.length == 0)
                throw new LeafException("No children to search through");

            foreach (size_t i, child; this.children)
            {
                if (child == data)
                    return i;
            }
            throw new LeafException("Could not find child node");
        }

        leaf get_child_by_data(leaf_type data)
        {
            return this.children[this.search_children_by_data(data)];
        }

        /** Returns true if this leaf has 
          the given node as a child
          Else false.
          */
        bool has_child(leaf child)
        {
            return this.children.canFind(child);
        }


        /** Returns true if this leaf has the given node
          as a parent.
          Else false.
          */
        bool has_parent(leaf parent)
        {
            return this.parent == parent;
        }

        public
        {
            leaf parent = null;
            leaf[] children;

            leaf_type data;

            bool is_root = false;
            bool terminal;
        }

        invariant
        {
            import std.format : format;
            import std.array : empty;

            assert((is_root && this.parent is null) || (!is_root && this.parent !is null),
                    format("Leaf invariant failure: root is %s, parent is %s",
                        this.is_root, this.parent));
            if (!is_root)
            {
                assert(this.parent !is null || this.children.empty,
                        "Leaf invariant failure: leaf neither parent, not child is populated");
            }
        }
    }
}

version(unittest)
{
    /** Compare two instances of AST trees.

      I'd love this function to be opEquals of the tree class,

      This requires the two trees to be <i>exactly</i> the same.
      i.e the order of the lists in which the children reside
      need to be identical. We could probably make 
      a version of this which doesnt require that, 
      using canFind and find from std.algorithm
      */

    template compare_trees (leaf_type)
    {
        import std.format: format;

        alias ast_t = AST!(leaf_type);
        alias tree_t = ast_t.tree;
        alias leaf_t = ast_t.leaf;

        bool compare_trees(tree_t a, tree_t b, bool function(leaf_t a, leaf_t b) compare_leaves)
        {

            assert(a.length == b.length);
            assert(compare_leaves(a.root, b.root), format("Root data didnt match. %s and %s", a.root.data, b.root.data));

            check_child_lengths_match(a.root, b.root);
            recursive_walk(a.root, b.root, compare_leaves);

            return true;
        }

        bool recursive_walk(leaf_t a,  leaf_t b, bool function(leaf_t a, leaf_t b) compare_leaves)
        {
            assert(check_child_lengths_match(a, b), format("Child lengths dont match. a %s : b %s", a.children.length, b.children.length));

            foreach(size_t i, child; a.children)
            {

                assert(check_child_lengths_match(child, b.children[i]));
                assert(compare_leaves(child, b.children[i]));
                assert(recursive_walk(child, b.children[i], compare_leaves));
            }

            return true;
        }

        bool check_leaf_matches(leaf_t a, leaf_t b)
        {
            return a.data == b.data;
        }

        bool check_child_lengths_match(leaf_t a, leaf_t b)
        {
            return a.children.length == b.children.length;
        }
    }
    
    template tree_factory ( leaf_type )
    {
        AST!(leaf_type).tree tree_factory(leaf_type[] leafdatalist)
        {
            auto t = new AST!(leaf_type).tree(); 

            foreach (d; leafdatalist)
            {
                t.add_leaf(d);
            }

            return t;
        }
    }

}


@BlerpTest("test_comparing_trees_matches") unittest
{
    class container
    {
        this(int d)
        {
            this.data = d;
        }
        int data;
    }

    auto t = new AST!(container).tree();

    t.add_leaf(new container(0));
    t.add_leaf(new container(10), t.root, false);
    t.add_leaf(new container(20), t.root, false);
    t.add_leaf(new container(30), t.front(), true);
    t.add_leaf(new container(40), t.front(), true);


    auto t2 = new AST!(container).tree();

    t2.add_leaf(new container(0));
    t2.add_leaf(new container(10), t2.root, false);
    t2.add_leaf(new container(20), t2.root, false);
    t2.add_leaf(new container(30), t2.front(), true);
    t2.add_leaf(new container(40), t2.front(), true);

    assert(t.length == t2.length);

    compare_trees!(container)(t, t2, (a, b){return a.data.data == b.data.data;}) ;
}

@BlerpTest("test_tree_add_root_item") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    assert(t.root !is null);
    assert(t.length == 1);

    assert(t.front() == 10);
}

/** This test tests a contract, which isnt in release code.
    So its almost like we're testing a test.
  */
@BlerpTest("test_tree_add_root_when_root_exists") unittest
{
    import core.exception : AssertError;

    auto t = new AST!(int).tree();
    t.add_leaf(10);
    try
        t.add_leaf(20);
    catch (AssertError)
    {
        assert(true);
        return;
    }

    assert(false, "Adding a non-root-node without a parent should be caught by the contract");
}

@BlerpTest("test_tree_add_child") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.front_item);

    assert(t.front() == 20);
    assert(t.root == 10);
}

@BlerpTest("test_get_child_by_data") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);
    t.add_leaf(30, t.root);
    t.add_leaf(40, t.root);

    assert(t.root.children.length == 3, "Number of children longer than expected");
    assert(t.root.get_child_by_data(40) == t.root.children[$ - 1]);
}

@BlerpTest("test_search_children") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);
    t.add_leaf(30, t.root);
    t.add_leaf(40, t.root);

    // Relies on opEquals of the leaf
    assert(t.root.children.length == 3, "Number of children more than expected");
    assert(t.root.search_children_by_data(20) == 0);
    assert(t.root.search_children_by_data(30) == 1);
    assert(t.root.search_children_by_data(40) == 2);
}

@BlerpTest("test_search_for_node") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);
    t.add_leaf(30, t.root.children[0]);
    t.add_leaf(40, t.root.children[0]);
    t.add_leaf(50, t.root.children[0].children[0]);

    assert(t.search_by_data(40).get.data == 40);
    assert(t.search_by_data(40).get is t.root.children[0].children[1]);

    assert(t.search_by_data(50).get.data == 50);
    assert(t.search_by_data(50).get is t.root.children[0].children[0].children[0]);

}

@BlerpTest("test_leaf_opEquals") unittest
{
    auto l = new AST!(int).leaf(10, null, false);
    auto l2 = new AST!(int).leaf(10, null, false);
    

    /* Really I'd like it so you could compare leaf objects
        but dlang's opEquals semantics are bad. 
        You can't specify an overload taking a particular type, only one that takes Object.
        So we cant do this.data == b.data.
        If this test starts failing, you've probably solved that problem.
    */   
    assert(l != l2, "Leaf object comparason failed");
    


    assert(l == l2.data, "Leaf data failed");
}

@BlerpTest("test_leaf_has_parent") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);

    assert(t.root.children[0].has_parent(t.root));
}

@BlerpTest("test_leaf_has_child") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);

    assert(t.root.has_child(t.root.children[0]));
}

@BlerpTest("test_leaf_doesnt_have_parent") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    t.add_leaf(20, t.root);
    t.add_leaf(20, t.root.children[0]);

    assert(!t.root.children[0].children[0].has_parent(t.root));
}

@BlerpTest("test_leaf_doesnt_have_child") unittest
{
    auto t = new AST!(int).tree();
    t.add_leaf(10);
    assert(t.root.data == 10);
    t.add_leaf(30, t.root);
    assert(t.root.children[0].data == 30);
    t.add_leaf(20, t.root.children[0], true);
    assert(t.root.children[0].children[0].data == 20);

    t.get_tree_graph_dot("test_leaf_doesnt_have_child.dot");

    assert(!t.root.has_child(t.root.children[0].children[0]));
}

/** Test adding terminal leaves with the same data as the front leaf.
  This is unlikely to happen during normal use because each node is probably a different
  object. 
  But, for later optimisation, for tree nodes that are only types ( like keywords ) we might
  want to maintain a pool of objects and just add the same ones, instead of making new objects.
  */
@BlerpTest("test_leaves_with_same_data") unittest
{
    auto t = new AST!(int).tree();
    
    t.add_leaf(10);
    t.add_leaf(30, t.root);
    t.add_leaf(30, t.front, true);
}
