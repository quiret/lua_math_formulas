local createCalcDepGraphSystem = createCalcDepGraphSystem;
local createDependencyFirstIterator = createDependencyFirstIterator;

if not (createCalcDepGraphSystem) or 
   not (createDependencyFirstIterator) then
    error("unmet imports");
end

local assert = assert;

do
    local sys = createCalcDepGraphSystem();
    
    local root = sys.createStaticSortedNode();
    local sub1 = sys.createStaticSortedNode({ root });
    local sub2 = sys.createStaticSortedNode({ root });
    local sub3 = sys.createStaticSortedNode({ sub1, sub2 });
    
    local iterator = createDependencyFirstIterator();
    
    iterator.setCurrentNode(root);
    
    assert(iterator.isEnd() == false);
    assert(iterator.getCurrentNode() == root);
    iterator.next();
    assert(iterator.getCurrentNode() == sub1);
    iterator.next();
    assert(iterator.getCurrentNode() == sub2);
    iterator.next();
    assert(iterator.getCurrentNode() == sub3);
    iterator.next();
    assert(iterator.isEnd() == true);
end

do
    local sys = createCalcDepGraphSystem();
    
    local root = sys.createStaticSortedNode();
    local layer1 = sys.createStaticSortedNode({ root });
    local layer2 = sys.createStaticSortedNode({ layer1 });
    local interDep = sys.createStaticSortedNode({ layer1, layer2 });
    local layer1_2 = sys.createStaticSortedNode({ root });
    local layer1_3 = sys.createStaticSortedNode({ root });
    local multi_dep = sys.createStaticSortedNode({ layer1, layer1_2, layer1_3, interDep });
    local prev_exec = sys.createStaticSortedNode({ layer2 });
    
    local iterator = createDependencyFirstIterator();
    
    iterator.setCurrentNode(root);
    
    assert(iterator.isEnd() == false);
    assert(iterator.getCurrentNode() == root);
    iterator.next();
    assert(iterator.getCurrentNode() == layer1);
    iterator.next();
    assert(iterator.getCurrentNode() == layer2);
    iterator.next();
    assert(iterator.getCurrentNode() == prev_exec);
    iterator.next();
    assert(iterator.getCurrentNode() == interDep);
    iterator.next();
    assert(iterator.getCurrentNode() == layer1_2);
    iterator.next();
    assert(iterator.getCurrentNode() == layer1_3);
    iterator.next();
    assert(iterator.getCurrentNode() == multi_dep);
    iterator.next();
    assert(iterator.isEnd() == true);
end

do
    local sys = createCalcDepGraphSystem();
    
    local root1 = sys.createStaticSortedNode();
    local root2 = sys.createStaticSortedNode();
    local dependent = sys.createStaticSortedNode({ root1, root2 });
    
    local iterator = createDependencyFirstIterator();
    
    iterator.setCurrentNode(root1);
    
    assert(iterator.getCurrentNode() == root1);
    iterator.next();
    assert(iterator.isEnd() == true);
    
    iterator.setCurrentNode(root2);
    
    assert(iterator.getCurrentNode() == root2);
    iterator.next();
    assert(iterator.getCurrentNode() == dependent);
    iterator.next();
    assert(iterator.isEnd() == true);
end

do
    local sys = createCalcDepGraphSystem();
    
    local root = sys.createStaticSortedNode();
    local subLayer1 = sys.createStaticSortedNode({ root });
    local subLayer2 = sys.createStaticSortedNode({ subLayer1 });
    
    local idx = 1;
    
    sys.visitInvalidatedSubtree(
        subLayer1,
        function(cn)
            if (idx == 1) then
                assert(cn == root);
            elseif (idx == 2) then
                assert(cn == subLayer1);
            elseif (idx == 3) then
                assert(cn == subLayer2);
            end
            
            idx = idx + 1;
        end
    );
    
    assert( idx == 4 );
end

do
    local sys = createCalcDepGraphSystem();
    
    local root1 = sys.createStaticSortedNode();
    local root1_subLayer1 = sys.createStaticSortedNode({ root1 });
    local root1_obj1 = sys.createStaticSortedNode({ root1_subLayer1 });
    local root1_obj2 = sys.createStaticSortedNode({ root1_subLayer1 });
    local root2 = sys.createStaticSortedNode();
    local root2_subLayer1 = sys.createStaticSortedNode({ root2 });
    
    do
        local idx = 1;
        
        sys.visitInvalidatedSubtree(
            root1_obj1,
            function(cn)
                if (idx == 1) then
                    assert(cn == root1);
                elseif (idx == 2) then
                    assert(cn == root1_subLayer1);
                elseif (idx == 3) then
                    assert(cn == root1_obj1);
                end
                
                idx = idx + 1;
            end
        );
        
        assert( idx == 4 );
    end
    
    do
        local idx = 1;
        
        sys.visitInvalidatedSubtree(
            root1_subLayer1,
            function(cn)
                if (idx == 1) then
                    assert(cn == root1);
                elseif (idx == 2) then
                    assert(cn == root1_subLayer1);
                elseif (idx == 3) then
                    assert(cn == root1_obj1);
                elseif (idx == 4) then
                    assert(cn == root1_obj2);
                end
                
                idx = idx + 1;
            end
        );
        
        assert( idx == 5, "expected idx = 5, got " .. idx );
    end
    
    do
        local idx = 1;
        
        sys.visitInvalidatedSubtree(
            root2,
            function(cn)
                if (idx == 1) then
                    assert(cn == root2);
                elseif (idx == 2) then
                    assert(cn == root2_subLayer1);
                end
                
                idx = idx + 1;
            end
        );
        
        assert( idx == 3 );
    end
end

do
    local sys = createCalcDepGraphSystem();
    
    local root = sys.createStaticSortedNode();
    local layer1_sub1 = sys.createStaticSortedNode({ root });
    local layer1_sub2 = sys.createStaticSortedNode({ root });
    local endpoint = sys.createStaticSortedNode({ layer1_sub1, layer1_sub2 });
    
    local idx = 1;
    
    sys.visitInvalidatedSubtree(
        endpoint,
        function(cn)
            if (idx == 1) then
                assert(cn == root);
            elseif (idx == 2) then
                assert(cn == layer1_sub1);
            elseif (idx == 3) then
                assert(cn == layer1_sub2);
            elseif (idx == 4) then
                assert(cn == endpoint);
            end
            
            idx = idx + 1;
        end
    );
    
    assert( idx == 5 );
end