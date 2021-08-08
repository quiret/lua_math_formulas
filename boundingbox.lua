-- Optimizations.
local traceback = traceback;

function createBoundingBox2D()
    local bbox = {};
    
    local min_x = false;
    local max_x = false;
    local min_y = false;
    local max_y = false;
    
    function bbox.reset()
        min_x = false;
        max_x = false;
        min_y = false;
        max_y = false;
    end
    
    function bbox.setValues(new_min_x, new_max_x, new_min_y, new_max_y)
        min_x = new_min_x;
        max_x = new_max_x;
        min_y = new_min_y;
        max_y = new_max_y;
        
        if (max_y == nil) then
            traceback();
        end
    end
    
    function bbox.getValues()
        return min_x, max_x, min_y, max_y;
    end
    
    function bbox.accountBounds(new_min_x, new_max_x, new_min_y, new_max_y)
        if not (new_min_x) then return; end;
        
        if not (min_x) or (min_x > new_min_x) then
            min_x = new_min_x;
        end
        
        if not (min_y) or (min_y > new_min_y) then
            min_y = new_min_y;
        end
        
        if not (max_x) or (max_x < new_max_x) then
            max_x = new_max_x;
        end
        
        if not (max_y) or (max_y < new_max_y) then
            max_y = new_max_y;
        end
    end
    
    return bbox;
end