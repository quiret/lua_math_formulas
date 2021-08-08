-- Optimizations.
local _G = _G;
local setmetatable = setmetatable;
local table = table;
local ipairs = ipairs;
local pairs = pairs;
local assert = assert;
local assert_traceback = assert_traceback;
local type = type;

local GRAPH_DEBUG_WEAK_LINKS = true;

local _weak_kv_mt = { __mode = "kv" };
local _weak_k_mt = { __mode = "k" };

local function createNodeIterator(sub_ilist_cb, init_visit_info_cb, attempt_visit_cb)
    local iterator = {};
    
    local visited_nodes = {};
    setmetatable(visited_nodes, _weak_k_mt);
    
    -- Contains node that have been walked up to from root nodes.
    -- If a root node has been visited then the visitable nodes starting from it are
    -- inside this setmap.
    local explored_visitable_nodes = {};
    setmetatable(explored_visitable_nodes, _weak_kv_mt);
    
    local curNode = nil;
    local children = nil;
    local childTryIndex = nil;
    
    local exclusionCallback = nil;
    
    local function get_visit_info(node)
        local info = visited_nodes[node];
        
        if (info) then return info; end
        
        info = {
            has_visited = false,
            path_node = nil,
            children = nil,
            pick_child_index =  false
        };
        
        if (init_visit_info_cb) then
            local meta = {};
            init_visit_info_cb(meta);
            
            info.meta = meta;
        end
        
        visited_nodes[node] = info;
        
        return info;
    end
    
    function iterator.setExclusionCallback(cb)
        exclusionCallback = cb;
    end
    
    function iterator.setCurrentNode(node)
        iterator.leaveNode();
    
        curNode = node;
        
        if (curNode) then
            children = sub_ilist_cb(node);
            childTryIndex = 1;
            
            local visit_info = get_visit_info(curNode);
            visit_info.path_node = nil;
            
            -- We are no longer an explored visitable node.
            explored_visitable_nodes[node] = nil;
        end
    end
    
    function iterator.getCurrentNode()
        return curNode;
    end
    
    function iterator.isEnd()
        return ( curNode == nil );
    end
    
    local function attempt_visit_node(curNode, visit_info, from_node)
        if not (attempt_visit_cb) then
            return true;
        end
        
        return attempt_visit_cb(curNode, visit_info.meta, from_node);
    end
    
    function iterator.isExcludedNode(node)
        if not (exclusionCallback) then
            return false;
        end
        
        return exclusionCallback(node);
    end
    
    function iterator.next()
        assert(not (curNode == nil));
    
        while (true) do
            local tryChildNode = children[childTryIndex];
            
            if not (tryChildNode) then
                -- We have completed the curNode so finalize the walking of it.
                local prev_visit_info = get_visit_info(curNode);
                prev_visit_info.children = nil; -- so the GC can run properly.
                curNode = prev_visit_info.path_node;
                
                if (curNode == nil) then
                    break;
                end
                
                local visit_info = get_visit_info(curNode);
                children = visit_info.children;
                childTryIndex = visit_info.pick_child_index;
            else
                childTryIndex = childTryIndex + 1;
            
                -- For each node that we discover we want to visit each connection to other nodes
                -- from it. Exception: we quit walking by leaveNode.
        
                local next_visit_info = get_visit_info(tryChildNode);
                
                if (next_visit_info.has_visited == false) then
                    local has_already_been_explored = not (explored_visitable_nodes[tryChildNode] == nil);
                
                    if (has_already_been_explored) or (attempt_visit_node(tryChildNode, next_visit_info, curNode)) then
                        -- Do we actually care about this node?
                        if not (exclusionCallback) or not (exclusionCallback(tryChildNode)) then
                            next_visit_info.has_visited = true;
                            next_visit_info.path_node = curNode;
                            next_visit_info.pick_child_index = 1;
                            
                            local prevNode_visit_info = get_visit_info(curNode);
                            prevNode_visit_info.pick_child_index = childTryIndex;
                            prevNode_visit_info.children = children;    -- since we are not finished with the node yet.
                            
                            if (has_already_been_explored) then
                                -- If we somehow were an explored visitable node then we obviously are not anymore.
                                explored_visitable_nodes[tryChildNode] = nil;
                            end
                            
                            curNode = tryChildNode;
                            children = sub_ilist_cb(curNode);
                            childTryIndex = 1;
                            break;
                        else
                            if not (has_already_been_explored) then
                                -- We do not care, thus we add it to visitable nodes.
                                -- The standard way to leave this list is to start from this node using
                                -- setCurrentNode.
                                explored_visitable_nodes[tryChildNode] = tryChildNode;
                            end
                        end
                    end
                end
            end
        end
    end
    
    function iterator.leaveNode()
        -- To clean up left-over runtime data if the walking was prematurely finished.
        -- Only required if the iterator would not be picked up by the garbage collector.
        while not (curNode == nil) do
            -- Actually perform the remaining visiting-check for the children.
            local tryChildNode = children[childTryIndex];
            
            while not (tryChildNode == nil) do
                local childVisitInfo = get_visit_info(tryChildNode);
                
                if not (childVisitInfo.has_visited) and (explored_visitable_nodes[tryChildNode] == nil) then
                    local canVisit = attempt_visit_info(tryChildNode, childVisitInfo, curNode);
                    
                    if (canVisit) then
                        -- Have to add this node to the explored visitable nodes.
                        explored_visitable_nodes[tryChildNode] = tryChildNode;
                    end
                end
                
                childTryIndex = childTryIndex + 1;
                tryChildNode = children[childTryIndex];
            end
        
            local prev_visit_info = get_visit_info(curNode);
            prev_visit_info.children = nil;
            curNode = prev_visit_info.path_node;
            
            local next_visit_info = get_visit_info(curNode);
            children = next_visit_info.children;
            childTryIndex = next_visit_info.pick_child_index;
        end
    end
    
    function iterator.hasBeenVisited(node)
        return get_visit_info(node).has_visited;
    end
    
    -- The list of all nodes that are visitable in a graph is the list of root nodes not yet visited
    -- combined with the list of visitable explored nodes.
    
    function iterator.getExploredVisitableNodesSetmap()
        return explored_visitable_nodes;
    end
    
    function iterator.getMetaInfo(node)
        return get_visit_info(node).meta;
    end
    
    function iterator.getCurrentChildren()
        return children;
    end
    
    return iterator;
end
_G.createNodeIterator = createNodeIterator;

-- DEBUG HELPER.
local function is_node_in_deps(node, checkNode)
    local tree_iter = createNodeIterator(
        function(cn)
            return cn.getDependencies();
        end
    );
    
    tree_iter.setCurrentNode(node);
    
    while (tree_iter.isEnd() == false) do
        local curNode = tree_iter.getCurrentNode();
        
        if (curNode == checkNode) then
            return true;
        end
        
        tree_iter.next();
    end
    
    return false;
end

function createNodeAccumulator(sub_ilist_cb)
    local depsSetmap = {};
    
    local accumulator = {};

    -- Cached iterator.
    local tree_iter = createNodeIterator(sub_ilist_cb);

    function accumulator.walk(node)
        tree_iter.setCurrentNode(node);
        
        while (tree_iter.isEnd() == false) do
            local curNode = tree_iter.getCurrentNode();
            
            depsSetmap[curNode] = curNode;
            
            tree_iter.next();
        end
    end
    
    function accumulator.containsNode(node)
        return not (depsSetmap[node] == nil);
    end
    
    return accumulator;
end

function createCalcDepGraphSystem()
    local system = {};
    
    local all_nodes = {};
    setmetatable(all_nodes, _weak_kv_mt);

    -- Nodes whose pointers depend on complicated internals.
    local function createDynamicNode()
        local node = {};
        
        -- TO BE IMPLEMENTED BY THE USER.
        --[BEGIN]
        -- OPTION 1:
        function node.getDependentsSetmap()
            -- Returns an unordered setmap list of nodes that directly depend on this node.
            -- Has to be implemented because we need to know which nodes to walk to next during
            -- dependency graph walking.
            -- The ordering does not have to be consistent across invocations.
            return {};
        end
        
        -- OPTION 2:
        --[[
        function node.getDependentsSorted()
            -- Returns the same kind of list as OPTION 1 but it is an incremental array instead.
        end
        --]]
        
        function node.getDependencies()
            -- Returns an ordered list of nodes of fixed arrangement that this node directly depends on.
            -- Has to be implemented because we need to know when all dependencies have been met
            -- during graph walking.
            return {};
        end
        --[END]
        
        -- User-data for the runtime
        node.userdata = {};
        
        all_nodes[node] = node;
        
        return node;
    end
    system.createDynamicNode = createDynamicNode;
    
    function system.createDepNode()
        local node = createDynamicNode();
        
        local dependents = {};
        setmetatable(dependents, _weak_kv_mt);
        
        function node.setDependent(dep)
            dependents[dep] = dep;
        end
        
        function node.unsetDependent(dep)
            dependents[dep] = nil;
        end
        
        -- Use this function if a node is swapped with another and
        -- you want to keep the dependency graph connections intact.
        -- Anonymous users of this node may have registered themselves to it
        -- so you cannot know who should be updated to the new node, but this
        -- function does mitigate the problem.
        function node.swapDependents(otherNode)
            local otherDeps = otherNode.getDependentsSetmap();
            otherNode.setDependentsSetmap(dependents);
            dependents = otherDeps;
        end
        
        function node.setDependentsSetmap(deps)
            dependents = deps;
        end
        
        function node.getDependentsSetmap()
            return dependents;
        end
        
        return node;
    end
    
    -- Nodes with fixed tables for dependencies and dependents (graph connections).
    function system.createStaticNode(dependencies)
        if not (dependencies) then
            dependencies = {};
        end
        
        local node = createDynamicNode();
        
        local dependents = {};
        
        function node.addDependent(dep)
            -- DEBUG.
            assert_traceback(is_node_in_deps(node, dep) == false);
        
            -- Add dep to the list of nodes that depend on this node.
            dependents[dep] = dep;
        end
        
        function node.removeDependent(dep)
            dependents[dep] = nil;
        end
        
        function node.getDependentsSetmap()
            return dependents;
        end
        
        function node.getDependencies()
            return dependencies;
        end
        
        for m,n in ipairs(dependencies) do
            n.addDependent(node);
        end
        
        return node;
    end

    function system.createStaticSortedNode(dependencies)
        if not (dependencies) then
            dependencies = {};
        end
        
        local node = createDynamicNode();
        
        local dependents = {};
        
        function node.addDependent(dep)
            -- DEBUG.
            assert_traceback(is_node_in_deps(node, dep) == false);
        
            -- Add dep to the list of nodes that depend on this node.
            table.insert(dependents, dep);
        end
        
        function node.removeDependent(dep)
            tremove(dependents, dep);
        end
        
        function node.getDependentsSorted()
            return dependents;
        end
        
        function node.getDependencies()
            return dependencies;
        end
        
        for m,n in ipairs(dependencies) do
            n.addDependent(node);
        end
        
        return node;
    end
    
    function system.forAllRoots(callback)
        for m,n in pairs(all_nodes) do
            if (#n.getDependencies() == 0) then
                callback(n);
            end
        end
    end
    
    function system.visitEntireFromRoots(iterator, callback)
        -- TODO: we actually want a list of all elements which have all their dependencies calculated
        -- and are not part of a current calculation endeavor; in simple scenarios this is just the list
        -- of roots.
        
        local function walk_node(n)
            iterator.setCurrentNode(n);
            
            while not (iterator.isEnd()) do
                local curNode = iterator.getCurrentNode();
                
                callback(curNode);
            
                iterator.next();
            end        
        end
        
        for m,n in pairs(all_nodes) do
            if (#n.getDependencies() == 0) and not (iterator.isExcludedNode(n)) then
                walk_node(n);
            end
        end
        
        for m,n in pairs(iterator.getExploredVisitableNodesSetmap()) do
            if not (iterator.isExcludedNode(n)) then
                walk_node(n);
            end
        end
    end
    
    function system.visitInvalidatedSubtree(invalidated_node, visit_callback)
        -- This function call has invalidated node, thus we have to recalculate all dependents of node.
        local dependent_leafs = {};
        
        do
            local iterator = createNodeDependentsIterator();
            
            iterator.setCurrentNode(invalidated_node);
            
            while not (iterator.isEnd()) do
                local curNode = iterator.getCurrentNode();
                local curChildren = iterator.getCurrentChildren();
                
                if (#curChildren == 0) then
                    table.insert(dependent_leafs, curNode);
                end
                
                iterator.next();
            end
        end
        
        -- First calculate the set of nodes which are dependencies of the leaf nodes.
        local dep_accum = createNodeDependencyAccumulator();
        
        for m,n in ipairs(dependent_leafs) do
            dep_accum.walk(n);
        end
        
        -- Next we iterate over the graph but only account the nodes that are part of our subgraph.
        local iterator = createDependencyFirstIterator();
        iterator.setExclusionCallback(
            function(cn)
                return (dep_accum.containsNode(cn) == false);
            end
        );
        
        system.visitEntireFromRoots(
            iterator,
            visit_callback
        );
    end
    
    return system;
end

local function dependency_first_get_children(node)
    local sorted_cb = node.getDependentsSorted;
    
    if (sorted_cb) then
        return sorted_cb();
    else
        local deps_setmap = node.getDependentsSetmap();
        local deps_ordered = {};
        
        for m,n in pairs(deps_setmap) do
            table.insert(deps_ordered, n);
        end
        
        return deps_ordered;
    end
end

local function dependency_first_meta_init(meta)
    meta.visit_count = 0;
end

local function dependency_first_attempt_visit(node, meta, from_node)
    if not (meta.deps) then
        meta.deps = node.getDependencies();
    end
    
    -- Only visit if the node truly is part of the dependencies.
    -- Otherwise we could be a to-be-killed weakling.
    local is_an_actual_dep = false;
    
    for m,n in ipairs(meta.deps) do
        if (n == from_node) then
            is_an_actual_dep = true;
            break;
        end
    end
    
    if not (is_an_actual_dep) then
        if (GRAPH_DEBUG_WEAK_LINKS) then
            assert( false, "weak link detected" );
        end
        return false;
    end
    
    local new_visit_count = meta.visit_count + 1;
    
    meta.visit_count = new_visit_count;
    
    local can_visit = (new_visit_count == #meta.deps);
    
    -- Cleanup since we are not going to need this meta for visiting anymore.
    if (can_visit) then
        meta.deps = nil;
    end
    
    return can_visit;
end

-- In a dependency-first node visiting sheme we visit each node exactly once.
-- PROOF:
-- We traverse the entire tree of each root node.
-- Thus we visit each node of the graph at least once.
-- Since we decide to visit the children of each node once at maximum, we visit each node
-- exactly once.
-- If we visit each node exactly once, then each node to node relation is visited exactly once.
-- Thus each rule that picks any relation from each set of node-to-children relations does suffice the
-- correctness of the algorithm.
-- NOTES:
-- this algorithm can be computed in parallel by any amount of visitors.
function createDependencyFirstIterator()
    local iterator = createNodeIterator(
        dependency_first_get_children,
        dependency_first_meta_init,
        dependency_first_attempt_visit
    );
    
    return iterator;
end

function createNodeDependentsIterator()
    local iterator = createNodeIterator(
        dependency_first_get_children
    );
    
    return iterator;
end

function createNodeDependentsAccumulator()
    return createNodeAccumulator(dependency_first_get_children);
end

local function node_get_dependencies(node)
    return node.getDependencies();
end

function createNodeDependencyAccumulator()
    return createNodeAccumulator(node_get_dependencies);
end