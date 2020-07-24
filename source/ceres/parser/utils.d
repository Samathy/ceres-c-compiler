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

/** Returns true if the given runtime object's superclass is
  the same as the given type.
  */
template isChildOf(base) if (is(base == class))
{
    bool isChildOf(Object child)
    {
        return base.classinfo.isBaseOf(child.classinfo);
    }
}

/** 
  Returns true if the given runtime object's type is the given type
  I really don't know why this kinda template isnt in
  std.traits or something
  */
template isTypeOf(t) if (is(t == class))
{
    bool isTypeOf(Object obj)
    {
        return typeid(obj) == t.classinfo;
    }
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
        string get_tree_graph_dot()
        {
            return "";
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
        void add_leaf(leaf_type leaf_data, leaf parent = null)
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
                assert(this.front_item.data == leaf_data);
            }
            else if (parent !is null)
            {
                assert(this.root !is null);
                assert(this.front_item.data == leaf_data);
                //assert(this.root_item.parent.get_child_by_data(leaf_data).data == leaf_data);
            }
        }
        do
        {
            if (parent is null)
            {
                this.root_item = new leaf(leaf_data, null);
                this.front_item = this.root_item;
                this.length += 1;
                return;
            }
            else if (this.root_item == parent)
            {
                import std.format : format;

                this.front_item = new leaf(leaf_data, this.root_item);
                this.root_item.children ~= this.front_item;
                this.length += 1;
                return;
            }
            else
            {
                this.front_item = new leaf(leaf_data, parent);
                parent.children ~= this.front_item;
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
        this(leaf_type data, leaf parent)
        {
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

        public
        {
            leaf parent = null;
            leaf[] children;

            leaf_type data;

            bool is_root = false;
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
