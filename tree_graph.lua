-- Optimizations.
local ipairs = ipairs;
local assert = assert;
local error = error;

function createTreeNodeIterator(children_cb, parent_cb)
    local iterator = {};
    
    local endNode = nil;
    local curNode = nil;
    
    function iterator.setCurrentNode(node)
        curNode = node;
        endNode = parent_cb(curNode);
    end
    
    function iterator.getCurrentNode()
        return curNode;
    end
    
    function iterator.isEnd()
        return ( curNode == endNode );
    end
    
    local function get_item_idx_in_table(t, i)
        for m,n in ipairs(t) do
            if (n == i) then
                return m;
            end
        end
        
        error("assumed child node not found during tree iteration; has the tree been changed during walking?");
    end
    
    function iterator.next()
        local cur_children = children_cb(curNode);
        local tryNextChild = 1;
        
        while (true) do
            -- First try going down the child.
            local attemptCurNode = cur_children[tryNextChild];
            
            if (attemptCurNode) then
                curNode = attemptCurNode;
                break;
            end
        
            -- If there is no more child to go down to, then we try going along the next child
            -- of the parent.
            local prev_node = curNode;
            curNode = parent_cb(curNode);
            
            if (curNode == endNode) then
                -- Quit if we have no more siblings to go along by.
                break;
            end
            
            cur_children = children_cb(curNode);
            tryNextChild = get_item_idx_in_table(cur_children, prev_node) + 1;
        end
    end
    
    return iterator;
end