-- Optimizations.
local ipairs = ipairs;
local pairs = pairs;
local table = table;
local print = print;
local tostring = tostring;
local setmetatable = setmetatable;
local assert = assert;

-- Imports from other modules.
local createCalcDepGraphSystem = createCalcDepGraphSystem;
local createDependencyFirstIterator = createDependencyFirstIterator;
local createBoundingBox2D = createBoundingBox2D;
local createTreeNodeIterator = createTreeNodeIterator;

local MATH_GLOBAL_DEBUG = false;

function formula_debug(isdebug)
    MATH_GLOBAL_DEBUG = not not (isdebug);
end

local function debugmsg(msg)
    if (#msg == 0) then return; end;

    if not (localPlayer) then
        print(msg);
    else
        outputDebugString(msg);
    end
end

local function cloneIndexedTable(t)
    if not (t) then
        return {};
    end

    local new = {};
    
    for m,n in ipairs(t) do
        new[m] = n;
    end
    
    return new;
end

local function tremove(t, i)
    for m,n in ipairs(t) do
        if (n == i) then
            table.remove(t, m);
            break;
        end
    end
end

local function thasitem(list, a)
    for m,n in ipairs(list) do
        if (n == a) then
            return true;
        end
    end
    
    return false;
end

local function tcontentstr(t)
    local str = "{";
    
    if (#t > 0) then
        str = str .. tostring(t[1]);
        
        for n=2,#t do
            str = str .. ", " .. tostring(t[n]);
        end
    end
    
    return str .. "}";
end

local function tisempty(t)
    for _,__ in pairs(t) do
        return false;
    end
    return true;
end

-- There are better algorithms out there but this does the job in Lua pretty well.
local function cutset(a, b)
    local cloned = cloneIndexedTable(a);
    
    local n = 1;
    local num_items = #cloned;
    
    while ( n <= num_items ) do
        local item = cloned[n];
    
        if not (thasitem(b, item)) then
            table.remove(cloned, n);
            num_items = num_items - 1;
        else
            n = n + 1;
        end
    end
    
    return cloned;
end

local function splitset(a, b)
    local n = 1;
    local num_items = #a;
    
    while ( n <= num_items ) do
        local item = a[n];
    
        if (thasitem(b, item)) then
            table.remove(a, n);
            num_items = num_items - 1;
        else
            n = n + 1;
        end
    end
end

-- Meta-table for weak keys and values.
local _wkv_mt = { __mode = "kv" };

function createFormulaLayoutManager(hint_name, MATH_LOCAL_DEBUG)
    local manager = {};
    
    -- Graph system for the calculation clouds and nodes.
    local dependency_sys = createCalcDepGraphSystem();
    
    local function createCloudManager(
        data_init_cb, data_reset_cb, data_copyover_cb, twoitem_calc_cb, node_get_data_cb, node_get_dep_cb, node_get_childcount_cb, node_contains_node_cb,
        data_paramstring_init_cb, data_paramstring_append_cb, data_paramstring_encapsulate_cb, node_get_paramstring_cb
    )
        -- Contains interdependent sets of rule-nodes. Each set represents one
        -- state of calculation.
        local calculation_clouds = {};
        setmetatable(calculation_clouds, _wkv_mt);
        
        local cloudMan = {};

        local function createCalculationCloud(calcNodes)
            calcNodes = cloneIndexedTable(calcNodes);
        
            -- Used for storing calculation data.
            local meta = {};
            
            data_init_cb(meta);
            
            -- Used for sheduling the calculation in dependency-order.
            local dependency_node = dependency_sys.createDepNode();
            
            for m,n in ipairs(calcNodes) do
                node_get_dep_cb(n).setDependent(dependency_node);
            end
            
            local cloudUseCount = 1;
        
            local cloud = {};
            
            function cloud.reference()
                cloudUseCount = cloudUseCount + 1;
            end
            
            function cloud.addNode(c)
                table.insert(calcNodes, c);
                node_get_dep_cb(c).setDependent(dependency_node);
            end
            
            function cloud.removeNode(c)
                tremove(calcNodes, c);
                node_get_dep_cb(c).unsetDependent(dependency_node);
            end
            
            function cloud.removeNodes(nodelist)
                for m,n in ipairs(nodelist) do
                    tremove(calcNodes, n);
                    node_get_dep_cb(n).unsetDependent(dependency_node);
                end
            end
            
            function cloud.getPartialCalcNodes()
                return calcNodes;
            end
            
            local subclouds = {};
            
            function cloud.getSubClouds()
                return subclouds;
            end
            
            function cloud.addSubCloud(c)
                table.insert(subclouds, c);
                c.getDependencyNode().setDependent(dependency_node);
            end
            
            function cloud.setSubClouds(sub)
                assert(#subclouds == 0);
                subclouds = sub;
                
                for m,n in ipairs(subclouds) do
                    n.getDependencyNode().setDependent(dependency_node);
                end
            end
            
            function cloud.hasNoSubClouds()
                return ( #subclouds == 0 );
            end
            
            function cloud.getNodeCount()
                local numNodes = 0;
                
                for m,n in ipairs(calcNodes) do
                    numNodes = numNodes + node_get_childcount_cb(n);
                end
                
                for m,n in ipairs(subclouds) do
                    numNodes = numNodes + n.getNodeCount();
                end
                
                return numNodes;
            end
            
            function cloud.containsNode(node)
                for m,n in ipairs(calcNodes) do
                    if (node_contains_node_cb(n, node)) then
                        return true;
                    end
                end
                
                for m,n in ipairs(subclouds) do
                    if (n.containsNode(node)) then
                        return true;
                    end
                end
                
                return false;
            end
            
            function cloud.toparamstring()
                local paramstring = {};
                data_paramstring_init_cb(paramstring);
                                
                local function append_str_subcloud(subcloud)
                    local sub_paramstring = subcloud.toparamstring();
                    
                    data_paramstring_append_cb(paramstring, sub_paramstring);
                end
                
                for m,n in ipairs(subclouds) do
                    append_str_subcloud(n);
                end
                
                for m,n in ipairs(calcNodes) do
                    local sub_paramstring = node_get_paramstring_cb(n);
                    
                    data_paramstring_append_cb(paramstring, sub_paramstring);
                end
                
                data_paramstring_encapsulate_cb(paramstring);
                
                return paramstring;
            end
            
            function cloud.tostring()
                local paramstring = cloud.toparamstring();
                
                if not (paramstring) then return ""; end;
                
                return data_paramstring_tostring(paramstring);
            end
            
            local _tmp_calc_data = {};
            data_init_cb(_tmp_calc_data);
            
            function cloud.calculate()
                -- Before you can calculate this cloud, you have to calculate all dependencies.
                
                data_reset_cb(meta);
                
                local function accountSubCloud(subCloud)
                    local sub_meta = subCloud.getMeta();
                    
                    twoitem_calc_cb(meta, sub_meta);
                end
                
                for m,n in ipairs(subclouds) do
                    accountSubCloud(n);
                end
                
                for m,n in ipairs(calcNodes) do
                    node_get_data_cb(_tmp_calc_data, n);
                    
                    twoitem_calc_cb(meta, _tmp_calc_data);
                end
            end
            
            function cloud.getMeta()
                return meta;
            end
            
            function cloud.clone()
                local cloned = createCalculationCloud(calcNodes);
                cloned.setSubClouds(cloneIndexedTable(subclouds));
                data_copyover_cb(cloned.getMeta(), meta);
                
                return cloned;
            end
            
            function cloud.extend(item)
                if (cloudUseCount == 1) then
                    cloud.addNode(item);
                    return cloud;
                end
                
                local newCloud = cloud.clone();
                newCloud.addNode(item);
                return newCloud;
            end
            
            function cloud.drop()
                if (cloudUseCount == 1) then
                    for m,n in ipairs(calcNodes) do
                        node_get_dep_cb(n).unsetDependent(dependency_node);
                    end
                    
                    for m,n in ipairs(subclouds) do
                        n.getDependencyNode().unsetDependent(dependency_node);
                    end
                
                    calculation_clouds[cloud] = nil;
                end
            end
            
            function dependency_node.calculate()
                cloud.calculate();
            end
            
            function cloud.getDependencyNode()
                return dependency_node;
            end
            
            function dependency_node.getDependencies()
                local deps = {};
                
                for m,n in ipairs(subclouds) do
                    table.insert(deps, n.getDependencyNode());
                end
                
                for m,n in ipairs(calcNodes) do
                    table.insert(deps, node_get_dep_cb(n));
                end
                
                return deps;
            end
        
            calculation_clouds[cloud] = cloud;
            
            return cloud;
        end
        cloudMan.createCalculationCloud = createCalculationCloud;
        
        local function find_biggest_common_nodeset(find_nodes)
            local maxcount = false;
            local set = false;
            local source_cloud = false;
            
            for m,n in pairs(calculation_clouds) do
                local common_set = cutset(n.getPartialCalcNodes(), find_nodes);
                
                local common_set_size = #common_set;
                
                if (common_set_size > 0) then
                    if (maxcount == false) or (maxcount < common_set_size) then
                        maxcount = common_set_size;
                        set = common_set;
                        source_cloud = n;
                    end
                end
            end
            
            return set, source_cloud;
        end
        
        -- Greedy-find best overlaps of one cloud with other clouds.
        function cloudMan.greedyCloudAcquire(_nodes)
            local new_nodes = cloneIndexedTable(_nodes);
            local take_child_clouds = {};
            local nodecount = #new_nodes;
            
            while (true) do
                local common_set, cloud = find_biggest_common_nodeset(new_nodes);
                
                if not (common_set) then
                    break;
                end
                
                local common_set_size = #common_set;
                
                if (MATH_GLOBAL_DEBUG) or (MATH_LOCAL_DEBUG) then
                    debugmsg("found common subset size: " .. common_set_size);
                end
                
                local cs_same_size_as_request = (common_set_size == nodecount);
                local cs_same_size_as_found = false;
                
                if (cloud.hasNoSubClouds()) then
                    cs_same_size_as_found = (common_set_size == cloud.getNodeCount());
                end
                
                if (cs_same_size_as_request) and (cs_same_size_as_found) and (#take_child_clouds == 0) then
                    cloud.reference();
                    return cloud;
                end
                
                if (cs_same_size_as_found) then
                    if (MATH_GLOBAL_DEBUG) or (MATH_LOCAL_DEBUG) then
                        debugmsg("cset entire size of source cloud, taking entire...");
                    end
                
                    table.insert(take_child_clouds, cloud);
                    cloud.reference();
                else
                    cloud.removeNodes(common_set);
                    
                    local newCloud = createCalculationCloud(common_set);
                    cloud.addSubCloud(newCloud);
                    newCloud.reference();
                    table.insert(take_child_clouds, newCloud);
                end
            
                splitset(new_nodes, common_set);
                
                nodecount = #new_nodes;
                
                if (cs_same_size_as_request) then
                    break;
                end
            end
            
            if (MATH_GLOBAL_DEBUG) or (MATH_LOCAL_DEBUG) then
                if (#take_child_clouds == 0) then
                    debugmsg("greedy-cloud-acquire: not sharing with any other clouds");
                end
            end
            
            local newCloud = createCalculationCloud(new_nodes);
            newCloud.setSubClouds(take_child_clouds);
            
            return newCloud;
        end
        
        function cloudMan.getClouds()
            return calculation_clouds;
        end
        
        return cloudMan;
    end
    
    local function bbox_paramstring_init(data)
        data.x_minstr = false;
        data.x_maxstr = false;
        data.y_minstr = false;
        data.y_maxstr = false;
        data.is_multi_entry = false;
        data.is_complex = false;
    end
    
    local function bbox_paramstring_append(data, append_data)
        if (append_data.x_minstr) then
            if (data.x_minstr) then
                data.x_minstr = data.x_minstr .. ", ";
                data.x_maxstr = data.x_maxstr .. ", ";
                data.y_minstr = data.y_minstr .. ", ";
                data.y_maxstr = data.y_maxstr .. ", ";
                
                data.is_multi_entry = true;
            else
                data.x_minstr = "";
                data.x_maxstr = "";
                data.y_minstr = "";
                data.y_maxstr = "";
            end
        
            data.x_minstr = data.x_minstr .. append_data.x_minstr;
            data.x_maxstr = data.x_maxstr .. append_data.x_maxstr;
            data.y_minstr = data.y_minstr .. append_data.y_minstr;
            data.y_maxstr = data.y_maxstr .. append_data.y_maxstr;
        end
    end
    
    local function bbox_paramstring_encapsulate(data)
        if (data.is_multi_entry) then
            data.x_minstr = "min(" .. data.x_minstr .. ")";
            data.x_maxstr = "max(" .. data.x_maxstr .. ")";
            data.y_minstr = "min(" .. data.y_minstr .. ")";
            data.y_maxstr = "max(" .. data.y_maxstr .. ")";
            
            data.is_complex = false;
        end
    end
    
    local function bbox_paramstring_tostring(data)
        if not (data.x_minstr) then
            return "(empty)";
        end
    
        return
            "min(x) = " .. data.x_minstr .. ", " ..
            "max(x) = " .. data.x_maxstr .. ", " ..
            "min(y) = " .. data.y_minstr .. ", " ..
            "max(y) = " .. data.y_maxstr;
    end
    
    local function bbox_paramstring_from_node(node)
        local nodeCloud = node.getChildCloud();
        local paramstring = nodeCloud.toparamstring();
        
        local local_w, local_h = node.getSize();
        
        local x_minstr = paramstring.x_minstr;
        local x_maxstr = paramstring.x_maxstr;
        local y_minstr = paramstring.y_minstr;
        local y_maxstr = paramstring.y_maxstr;

        if not (x_minstr) then return false; end;
    
        if (local_w) and (local_h) then
            if not (x_minstr) then
                x_minstr = "";
                x_maxstr = "";
                y_minstr = "";
                y_maxstr = "";
            else
                x_minstr = x_minstr .. ", ";
                x_maxstr = x_maxstr .. ", ";
                y_minstr = y_minstr .. ", ";
                y_maxstr = y_maxstr .. ", ";
                
                paramstring.is_multi_entry = true;
            end
        
            x_minstr = x_minstr .. "0";
            x_maxstr = x_maxstr .. local_w;
            y_minstr  = y_minstr .. "0";
            y_maxstr = y_maxstr .. local_h;
        end
    
        if (paramstring.is_complex) then
            x_minstr = "(" .. x_minstr .. ")";
            x_maxstr = "(" .. x_maxstr .. ")";
            y_minstr = "(" .. y_minstr .. ")";
            y_maxstr = "(" .. y_maxstr .. ")";
        end
    
        x_minstr = local_x .. " + " .. x_minstr .. " * " .. local_scale;
        x_maxstr = local_x .. " + " .. x_maxstr .. " * " .. local_scale;
        y_minstr = local_y .. " + " .. y_minstr .. " * " .. local_scale;
        y_maxstr = local_y .. " + " .. y_maxstr .. " * " .. local_scale;
        
        paramstring.x_minstr = x_minstr;
        paramstring.x_maxstr = x_maxstr;
        paramstring.y_minstr = y_minstr;
        paramstring.y_maxstr = y_maxstr;
        
        paramstring.is_complex = true;
        
        return paramstring;
    end
    
    local function minmax_meta_init(data)
        data.bbox = createBoundingBox2D();
    end
    
    local function minmax_meta_reset(data)
        data.bbox.reset();
    end
    
    local function minmax_meta_copyfrom(dst, src)
        dst.bbox.setValues(src.bbox.getValues());
    end
    
    local function minmax_meta_twocalc(dst, calc)
        dst.bbox.accountBounds(calc.bbox.getValues());
    end
    
    local function minmax_meta_fromnode(data, node)
        local min_x, max_x, min_y, max_y = node.getParentSpaceValues();
    
        data.bbox.setValues(min_x, max_x, min_y, max_y);
    end
    
    local function minmax_meta_depnode(node)
        return node.getParentSpaceValuesNode();
    end
    
    local function minmax_meta_childcount(node)
        return node.getChildCloud().getNodeCount();
    end
    
    local function minmax_meta_containsnode(node, insider)
        return node.getChildCloud().containsNode(insider);
    end

    local function createMinMaxCloudManager()
        return createCloudManager(
            minmax_meta_init, minmax_meta_reset, minmax_meta_copyfrom, minmax_meta_twocalc,
            minmax_meta_fromnode, minmax_meta_depnode, minmax_meta_childcount, minmax_meta_containsnode,
            bbox_paramstring_init, bbox_paramstring_append, bbox_paramstring_encapsulate,
            bbox_paramstring_from_node
        );
    end
    
    local function border_minmax_meta_fromnode(data, node)
        local min_x, max_x, min_y, max_y = node.getParentSpaceBorderValues();
        
        data.bbox.setValues(min_x, max_x, min_y, max_y);
    end
    
    local function border_minmax_meta_depnode(node)
        return node.getParentSpaceBorderValuesNode();
    end
    
    local function border_minmax_meta_childcount(node)
        return node.getBorderCloud().getNodeCount();
    end
    
    local function border_minmax_meta_containsnode(node, insider)
        return node.getBorderCloud().containsNode(insider);
    end
    
    local function border_bbox_paramstring_from_node(node)
        -- TODO implement when actually required.
        assert( false );
    end
    
    local function createBorderMinMaxCloudManager()
        return createCloudManager(
            minmax_meta_init, minmax_meta_reset, minmax_meta_copyfrom, minmax_meta_twocalc,
            border_minmax_meta_fromnode, border_minmax_meta_depnode, border_minmax_meta_childcount, border_minmax_meta_containsnode,
            bbox_paramstring_init, bbox_paramstring_append, bbox_paramstring_encapsulate,
            border_bbox_paramstring_from_node
        );
    end
    
    local globalCloudMan = createMinMaxCloudManager();
    local globalBorderCloudMan = createBorderMinMaxCloudManager();
    
    -- All nodes of this system, but not limited to one drawing hierarchy.
    local nodes = {};
    
    setmetatable(nodes, _wkv_mt);
    
    -- Creates a node that is executed after calculation of the dependencies.
    function manager.createLayoutNode(init_x, init_y, init_w, init_h, init_scale, parentNode, dependingOnNodes, nearby_callback, init_children_callback)
        local local_x = init_x;
        local local_y = init_y;
        local local_w = init_w;
        local local_h = init_h;
        local local_scale = init_scale;
    
        local node = {};
        
        function node.setInitPos(x, y)
            init_x = x;
            init_y = y;
        end
        
        function node.setInitSize(w, h)
            init_w = w;
            init_h = h;
        end
        
        function node.setInitScale(scale)
            init_scale = scale;
        end
        
        local function check_parent_of_deps(deps)
            for m,n in ipairs(deps) do
                if not (n.getParent() == parentNode) then
                    error("dependencies of node must have same parent as node", 3);
                end
            end
        end
        
        local children_callbacks = {};
        
        -- Calculation hierarchy dependency nodes.        
        local local_dep_node = dependency_sys.createDepNode();
        
        function node.getLocalDepNode()
            return local_dep_node;
        end
        
        -- Children nodes in the hierarchy.
        local childrenNodes = {};
        
        local dependencies = {};
        
        local function createDependency(dcnodes, cb)
            check_parent_of_deps(dcnodes);
        
            local depinfo = {};
            
            depinfo.cloud = globalCloudMan.greedyCloudAcquire(dcnodes);
            depinfo.cb = cb;
            
            depinfo.cloud.getDependencyNode().setDependent(local_dep_node);
            
            dependencies[depinfo] = depinfo;
            
            return depinfo;
        end
        
        local function removeDependency(depinfo)
            depinfo.cloud.getDependencyNode().unsetDependent(local_dep_node);
        
            dependencies[depinfo] = nil;
        end
        
        if (dependingOnNodes) then        
            createDependency(dependingOnNodes, nearby_callback);
        end
        
        -- Border calculation semantics.
        local border_left = 0;
        local border_right = 0;
        local border_top = 0;
        local border_bottom = 0;
        
        local borderNodeCloud = globalBorderCloudMan.greedyCloudAcquire(nil);
        
        function node.setBorder(t, l, b, r)
            border_top = t;
            border_left = l;
            border_bottom = b;
            border_right = r;
        end
        
        function node.getBorder()
            return border_top, border_left, border_bottom, border_right;
        end
        
        function node.getBorderCloud()
            return borderNodeCloud;
        end
        
        local border_dependencies = {};
        
        -- Cloud for calculation of the entire layout.
        local nodeCloud = globalCloudMan.greedyCloudAcquire(nil);
        
        local local_tmp_bbox = createBoundingBox2D();
        
        local abs_x = false;
        local abs_y = false;
        local abs_scale = false;
        
        function local_dep_node.calculate()
            -- Initialize the local parameters.
            local_x = init_x;
            local_y = init_y;
            local_w = init_w;
            local_h = init_h;
            local_scale = init_scale;
        
            for m,n in pairs(dependencies) do
                local depCloud = n.cloud;
                
                local dep_min_x, dep_max_x, dep_min_y, dep_max_y = depCloud.getMeta().bbox.getValues();

                local new_local_x, new_local_y, new_local_w, new_local_h, new_local_scale =
                    n.cb( dep_min_x, dep_max_x, dep_min_y, dep_max_y );
                    
                if (new_local_x) then
                    local_x = new_local_x;
                end
                
                if (new_local_y) then
                    local_y = new_local_y;
                end
                
                if (new_local_w) then
                    local_w = new_local_w;
                end
                
                if (new_local_h) then
                    local_h = new_local_h;
                end
                
                if (new_local_scale) then
                    local_scale = new_local_scale;
                end
            end
            
            local function calc_child_bbox()
                local_tmp_bbox.setValues(nodeCloud.getMeta().bbox.getValues());
                
                if (local_w) and (local_h) then
                    local_tmp_bbox.accountBounds(0, local_w, 0, local_h);
                end
            
                return local_tmp_bbox.getValues();
            end
            
            if (#border_dependencies >= 1) then
                for m,n in ipairs(border_dependencies) do
                    local_tmp_bbox.setValues(borderNodeCloud.getMeta().bbox.getValues());
                    
                    if (local_w) and (local_h) then
                        local border_minx = -border_left;
                        local border_maxx = local_w + border_right;
                        local border_miny = -border_top;
                        local border_maxy = local_h + border_bottom;
                        
                        local_tmp_bbox.accountBounds(border_minx, border_maxx, border_miny, border_maxy);
                    end
                    
                    local curobj_border_minx, curobj_border_maxx, curobj_border_miny, curobj_border_maxy = local_tmp_bbox.getValues();
                    
                    local child_local_minx, child_local_maxx, child_local_miny, child_local_maxy = calc_child_bbox();
                    
                    local curobj_border_left = ( child_local_minx - curobj_border_minx );
                    local curobj_border_right = ( curobj_border_maxx - child_local_maxx );
                    local curobj_border_top = ( child_local_miny - curobj_border_miny );
                    local curobj_border_bottom = ( curobj_border_maxy - child_local_maxy );
                
                    local depCloud = n.bound_cloud;
                    local borderCloud = n.cloud;
                    
                    local border_minx, border_maxx, border_miny, border_maxy = borderCloud.getMeta().bbox.getValues();
                    local dep_minx, dep_maxx, dep_miny, dep_maxy = depCloud.getMeta().bbox.getValues();
                    
                    local dep_border_left = ( dep_minx - border_minx );
                    local dep_border_top = ( dep_miny - border_miny );
                    local dep_border_right = ( border_maxx - dep_maxx );
                    local dep_border_bottom = ( border_maxy - dep_maxy );
                    
                    if (dep_border_left < curobj_border_left) then
                        dep_border_left = curobj_border_left;
                    end
                    
                    if (dep_border_top < curobj_border_top) then
                        dep_border_top = curobj_border_top;
                    end
                    
                    if (dep_border_right < curobj_border_right) then
                        dep_border_right = curobj_border_right;
                    end
                    
                    if (dep_border_bottom < curobj_border_bottom) then
                        dep_border_bottom = curobj_border_bottom;
                    end
                    
                    local keepdist_minx = ( dep_minx - dep_border_left );
                    local keepdist_maxx = ( dep_maxx + dep_border_right );
                    local keepdist_miny = ( dep_miny - dep_border_top );
                    local keepdist_maxy =  ( dep_maxy + dep_border_bottom );
                    
                    local new_local_x, new_local_y, new_local_w, new_local_h, new_local_scale = n.cb( keepdist_minx, keepdist_maxx, keepdist_miny, keepdist_maxy );
                    
                    if (new_local_x) then
                        local_x = new_local_x;
                    end
                    
                    if (new_local_y) then
                        local_y = new_local_y;
                    end
                    
                    if (new_local_w) then
                        local_w = new_local_w;
                    end
                    
                    if (new_local_h) then
                        local_h = new_local_h;
                    end
                    
                    if (new_local_scale) then
                        local_scale = new_local_scale;
                    end
                end
            end

            for m,n in ipairs(children_callbacks) do
                local child_local_minx, child_local_maxx, child_local_miny, child_local_maxy = calc_child_bbox();
            
                local new_local_x, new_local_y, new_local_w, new_local_h, new_local_scale =
                    n(child_local_minx, child_local_maxx, child_local_miny, child_local_maxy);
                    
                if (new_local_x) then
                    local_x = new_local_x;
                end
                
                if (new_local_y) then
                    local_y = new_local_y;
                end
                
                if (new_local_w) then
                    local_w = new_local_w;
                end
                
                if (new_local_h) then
                    local_h = new_local_h;
                end
                
                if (new_local_scale) then
                    local_scale = new_local_scale;
                end
            end
        end
        
        function local_dep_node.getDependencies()
            local deps = {};
            
            for m,n in pairs(dependencies) do
                table.insert(deps, n.cloud.getDependencyNode());
            end
            
            for m,n in ipairs(border_dependencies) do
                table.insert(deps, n.cloud.getDependencyNode());
                table.insert(deps, n.bound_cloud.getDependencyNode());
            end
            
            local has_border_deps = (#border_dependencies >= 1);
            
            if (has_border_deps) then
                table.insert(deps, borderNodeCloud.getDependencyNode());
            end
            
            if (#children_callbacks >= 1) or (has_border_deps) then
                table.insert(deps, nodeCloud.getDependencyNode());
            end
            
            return deps;
        end

        function node.addChildrenCallback(cb)
            table.insert(children_callbacks, cb);
            
            if (#children_callbacks == 1) then
                nodeCloud.getDependencyNode().setDependent(local_dep_node);
            end
        end
        
        function node.removeChildrenCallback(cb)
            tremove(children_callbacks, cb);
            
            if (#children_callbacks == 0) and (#border_dependencies == 0) then
                nodeCloud.getDependencyNode().unsetDependent(local_dep_node);
            end
        end
        
        function node.clearChildrenCallbacks()
            children_callbacks = {};
            
            if (#border_dependencies == 0) then
                nodeCloud.getDependencyNode().unsetDependent(local_dep_node);
            end
        end
        
        node.addChildrenCallback(init_children_callback);
        
        local abs_dep_node = dependency_sys.createDepNode();
        
        function abs_dep_node.calculate()
            local parent_x, parent_y, parent_scale;
        
            if (parentNode) then
                parent_x, parent_y = parentNode.getAbsolutePos();
                parent_scale = parentNode.getAbsoluteScale();
            else
                parent_x = 0;
                parent_y = 0;
                parent_scale = 1;
            end
           
            -- Calculate the absolute parameters of the node.
            -- Should be fine since we have proper local parameters now.
            if (parent_x) and (parent_y) and (parent_scale) and (local_x) and (local_y) then
                abs_x = ( local_x * parent_scale + parent_x );
                abs_y = ( local_y * parent_scale + parent_y );
            else
                abs_x = false;
                abs_y = false;
            end
            
            if (parent_scale) and (local_scale) then
                abs_scale = ( parent_scale * local_scale );
            else
                abs_scale = false;
            end
        end
        
        function node.getAbsoluteDepNode()
            return abs_dep_node;
        end
        
        function abs_dep_node.getDependencies()
            local deps = {};
            
            table.insert(deps, local_dep_node);
            
            if (parentNode) then
                table.insert(deps, parentNode.getAbsoluteDepNode());
            end
            
            return deps;
        end
        
        local_dep_node.setDependent(abs_dep_node);
        
        -- Create a node that represents the cloud values but in parent space.
        -- This node calculates a bounding box that includes this node.
        local parentspace_cloud_values_node = dependency_sys.createDepNode();
        
        local pspace_bbox = createBoundingBox2D();
        local pspace_apx_min, pspace_apx_max, pspace_apy_min, pspace_apy_max;
        
        function parentspace_cloud_values_node.calculate()
            pspace_bbox.setValues(nodeCloud.getMeta().bbox.getValues());
            
            if (local_w) and (local_h) then
                -- Do include ourselves into the bounding box, if we have an area.
                pspace_bbox.accountBounds(0, local_w, 0, local_h);
            end
            
            -- Transform the values into parent space.
            local apx_min, apx_max, apy_min, apy_max = pspace_bbox.getValues();

            pspace_apx_min = false;
            pspace_apx_max = false;
            pspace_apy_min = false;
            pspace_apy_max = false;
        
            if (apx_min) and (local_x) and (local_y) and (local_scale) then
                pspace_apx_min = local_x + apx_min * local_scale;
                pspace_apx_max = local_x + apx_max * local_scale;
                pspace_apy_min = local_y + apy_min * local_scale;
                pspace_apy_max = local_y + apy_max * local_scale;
            end
        end
        
        function node.getParentSpaceValues()
            return pspace_apx_min, pspace_apx_max, pspace_apy_min, pspace_apy_max;
        end
        
        function node.getParentSpaceString()
            local paramstring = bbox_paramstring_from_node(node);
            
            return bbox_paramstring_tostring(paramstring);
        end

        function parentspace_cloud_values_node.getDependencies()
            local deps = {};
            
            table.insert(deps, nodeCloud.getDependencyNode());
            table.insert(deps, local_dep_node);
            
            return deps;
        end
        
        nodeCloud.getDependencyNode().setDependent(parentspace_cloud_values_node);
        local_dep_node.setDependent(parentspace_cloud_values_node);
        
        function node.getParentSpaceValuesNode()
            return parentspace_cloud_values_node;
        end
        
        -- For the border result but including the children and the current node.
        local parent_space_border_values_node = dependency_sys.createDepNode();
        
        local pspace_border_minx = nil;
        local pspace_border_maxx = nil;
        local pspace_border_miny = nil;
        local pspace_border_maxy = nil;
        
        local pspace_tmp_bbox = createBoundingBox2D();
        
        function parent_space_border_values_node.calculate()
            pspace_tmp_bbox.setValues(borderNodeCloud.getMeta().bbox.getValues());
            
            if (local_w) and (local_h) then
                local localbox_minx = -border_left;
                local localbox_maxx = local_w + border_right;
                local localbox_miny = -border_top;
                local localbox_maxy = local_h + border_bottom;
                
                pspace_tmp_bbox.accountBounds(localbox_minx, localbox_maxx, localbox_miny, localbox_maxy);
            end
            
            local minx, maxx, miny, maxy = pspace_tmp_bbox.getValues();
            
            -- Transform the values into parent-space, if possible.
            pspace_border_minx = false;
            pspace_border_maxx = false;
            pspace_border_miny = false;
            pspace_border_maxy = false;
            
            if (minx) and (local_x) and (local_y) and (local_scale) then
                pspace_border_minx = local_x + minx * local_scale;
                pspace_border_maxx = local_x + maxx * local_scale;
                pspace_border_miny = local_y + miny * local_scale;
                pspace_border_maxy = local_y + maxy * local_scale;
            end
        end
        
        function parent_space_border_values_node.getDependencies()
            local deps = {};
            
            table.insert(deps, borderNodeCloud.getDependencyNode());
            table.insert(deps, local_dep_node);
            
            return deps;
        end
        
        borderNodeCloud.getDependencyNode().setDependent(parent_space_border_values_node);
        local_dep_node.setDependent(parent_space_border_values_node);
        
        function node.getParentSpaceBorderValuesNode()
            return parent_space_border_values_node;
        end
        
        function node.getParentSpaceBorderValues()
            return pspace_border_minx, pspace_border_maxx, pspace_border_miny, pspace_border_maxy;
        end
        
        -- dcnodes has to contain nearby nodes of this node (same parent).
        function node.addDependency(dcnodes, cb)
            local depinfo = createDependency(dcnodes, cb);
            return depinfo.cloud;
        end
        
        function node.doesDependOnNode(depnode)
            for m,n in pairs(dependencies) do
                if (n.cloud.containsNode(depnode)) then
                    return true;
                end
            end
            
            return false;
        end
        
        function node.addBorderDependency(deps, cb)
            check_parent_of_deps(deps);
        
            local depinfo = {};
            
            depinfo.cloud = globalBorderCloudMan.greedyCloudAcquire(deps);
            depinfo.bound_cloud = globalCloudMan.greedyCloudAcquire(deps);
            depinfo.cb = cb;
            
            depinfo.cloud.getDependencyNode().setDependent(local_dep_node);
            depinfo.bound_cloud.getDependencyNode().setDependent(local_dep_node);
            
            table.insert(border_dependencies, depinfo);

            if (#border_dependencies == 1) then
                nodeCloud.getDependencyNode().setDependent(local_dep_node);
                borderNodeCloud.getDependencyNode().setDependent(local_dep_node);
            end
 
            return depinfo.cloud;
        end
        
        function node.getLocalPos()
            return local_x, local_y;
        end
        
        function node.getSize()
            return local_w, local_h;
        end
        
        function node.getLocalScale()
            return local_scale;
        end
        
        function node.setAbsolutePos(x, y)
            abs_x = x;
            abs_y = y;
        end
        
        function node.getAbsolutePos()
            return abs_x, abs_y;
        end
        
        function node.getAbsoluteScale()
            return abs_scale;
        end
        
        function node.getParent()
            return parentNode;
        end
        
        local function detach_nodecloud()
            nodeCloud.getDependencyNode().unsetDependent(parentspace_cloud_values_node);
            if (#children_callbacks >= 1) or (#border_dependencies >= 1) then
                nodeCloud.getDependencyNode().unsetDependent(local_dep_node);
            end
            if (#border_dependencies >= 1) then
                borderNodeCloud.getDependencyNode().unsetDependent(local_dep_node);
            end
        end
        
        local function attach_nodecloud()
            nodeCloud.getDependencyNode().setDependent(parentspace_cloud_values_node);
            if (#children_callbacks >= 1) or (#border_dependencies >= 1) then
                nodeCloud.getDependencyNode().setDependent(local_dep_node);
            end
            if (#border_dependencies >= 1) then
                borderNodeCloud.getDependencyNode().setDependent(local_dep_node);
            end
        end
        
        local function detach_bordernodecloud()
            borderNodeCloud.getDependencyNode().unsetDependent(parent_space_border_values_node);
        end
        
        local function attach_bordernodecloud()
            borderNodeCloud.getDependencyNode().setDependent(parent_space_border_values_node);
        end
        
        function node.addChild(childNode)
            abs_dep_node.setDependent(childNode.getAbsoluteDepNode());  
            detach_nodecloud();
            detach_bordernodecloud();
            nodeCloud.drop();
            borderNodeCloud.drop();
            table.insert(childrenNodes, childNode);
            nodeCloud = globalCloudMan.greedyCloudAcquire(childrenNodes);
            borderNodeCloud = globalBorderCloudMan.greedyCloudAcquire(childrenNodes);
            attach_nodecloud();
            attach_bordernodecloud();
        end
        
        function node.removeChild(childNode)
            abs_dep_node.unsetDependent(childNode.getAbsoluteDepNode());
            detach_nodecloud();
            detach_bordernodecloud();
            nodeCloud.drop();
            borderNodeCloud.drop();
            tremove(childrenNodes, childNode);
            nodeCloud = globalCloudMan.greedyCloudAcquire(childrenNodes);
            borderNodeCloud = globalBorderCloudMan.greedyCloudAcquire(childrenNodes);
            attach_nodecloud();
            attach_bordernodecloud();
        end
        
        function node.getChildren()
            return childrenNodes;
        end
        
        function node.calculate()
            nodeCloud.calculate();
        end
        
        function node.mathstring()
            return node.getParentSpaceString();
        end
        
        function node.mathisprecalc()
            return nodeCloud.isCalculated();
        end
        
        function node.getValues()
            return node.getParentSpaceValues();
        end
        
        function node.getChildCloud()
            return nodeCloud;
        end
        
        function node.setParent(newParent)
            if (newParent == parentNode) then return; end;
            
            -- Check that the parent is not one of our children.
            do
                local tree_iter = createTreeNodeIterator(
                    function(node)
                        return node.getChildren();
                    end,
                    function(node)
                        return node.getParent();
                    end
                );
                
                tree_iter.setCurrentNode(node);
                
                while not (tree_iter.isEnd()) do
                    local curNode = tree_iter.getCurrentNode();
                    
                    assert(not (curNode == newParent), "new parent is part of our children; circle in layout tree detected");
                
                    tree_iter.next();
                end
            end
        
            if (parentNode) then
                parentNode.removeChild(node);
            end
            
            parentNode = newParent;
            
            if (newParent) then
                newParent.addChild(node);
            end
        end
        
        function node.getParent()
            return parentNode;
        end
        
        -- Add to the global node list.
        nodes[node] = node;
        
        if (parentNode) then
            parentNode.addChild(node);
        end
        
        return node;
    end

    local function fixup_node_TL(node, tl_x, tl_y, do_debug)
        local abs_x, abs_y = node.getAbsolutePos();
        
        if (abs_x) and (abs_y) then
            local new_abs_x = abs_x - tl_x;
            local new_abs_y = abs_y - tl_y;
            
            if (do_debug) then
                local nw, nh = node.getSize();
                
                local msgout = "x: " .. abs_x .. " -> " .. new_abs_x .. ", y: " .. abs_y .. " -> " .. new_abs_y;
                
                if not (nw) or not (nh) then
                    msgout = msgout .. " (no region)";
                end
            
                debugmsg(msgout);
            end
        
            node.setAbsolutePos(new_abs_x, new_abs_y);
        end
        
        local children = node.getChildren();
        
        for m,n in ipairs(children) do
            fixup_node_TL(n, tl_x, tl_y, do_debug);
        end
    end
    
    local function callback_calculate_node(node)
        node.calculate();
    end
    
    -- Arranges the nodes inside of the layout so that the calculation can be
    -- used for rendering, repositioning, scaling, etc.
    function manager.arrangeLayout()
        local do_debug = (MATH_GLOBAL_DEBUG) or (MATH_LOCAL_DEBUG);
    
        if (do_debug) then
            if (hint_name) then
                debugmsg("CALC OF: " .. hint_name);
            end
            debugmsg("STEP 1: calculate all constants for the point equations");
        end
        
        dependency_sys.visitEntireFromRoots(
            createDependencyFirstIterator(),
            callback_calculate_node
        );

        -- After population, we can calculate in clouds.
        if (do_debug) then
            debugmsg("STEP 2: calculate minimum and maximum coordinates");
        end
        
        for m,n in pairs(nodes) do
            if not (n.getParent()) then
                if (do_debug) then
                    debugmsg(n.mathstring() .. " [precalc: " .. tostring(n.mathisprecalc()) .. "]");
                end

                -- BLEH.
                
                if (do_debug) then
                    local min_x, max_x, min_y, max_y = n.getValues();
                    
                    if (min_x) then
                        debugmsg("min_x = " .. min_x .. ", max_x = " .. max_x .. ", min_y = " .. min_y .. ", max_y = " .. max_y);
                    end
                end
            end
        end
        
        if (do_debug) then
            debugmsg("STEP 3: fixup TL into node absolute positions");
        end
        
        for m,n in pairs(nodes) do
            if not (n.getParent()) then
                local minx, maxx, miny, maxy = n.getParentSpaceValues();
                
                fixup_node_TL(n, minx, miny, do_debug);
            end
        end
    end
    
    -- Arranges a single node.
    -- If there are dependencies of said node, then the dependencies have to be arranged before it; else you perform
    -- undefined behaviour.
    function manager.arrangeNode(node)
        -- An API limitation, we will get rid of this soon for more general code.
        if (node.getParent()) then
            return false;
        end
        
        -- TODO: improve this call; we want updates on demand instead.
        --node.invalidateMath();
        
        -- TODO: improve this invalidation.
        dependency_sys.visitInvalidatedSubtree(
            node.getLocalDepNode(),
            callback_calculate_node
        );
        
        -- FIXUP TopLeft.
        local minx, maxx, miny, maxy = node.getParentSpaceValues();
        
        fixup_node_TL(node, minx, miny);
        
        return true;
    end
    
    -- Debug function: returns the total amount of nodes alive.
    -- Nodes can be garbage collected.
    function manager.getNumNodes()
        local num = 0;
        
        for m,n in pairs(nodes) do
            num = num + 1;
        end
        
        return num;
    end
    
    -- Debug function: returns the total amount of calculation clouds alive.
    -- Clouds can be garbage collected.
    function manager.getNumMathClouds()
        local num = 0;
        
        for m,n in pairs(globalCloudMan.getClouds()) do
            num = num + 1;
        end
        
        return num;
    end
    
    return manager;
end