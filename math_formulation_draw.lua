-- Optimizations.
local dxDrawRectangle = dxDrawRectangle;
local dxDrawText = dxDrawText;
local dxDrawLine = dxDrawLine;
local dxGetFontHeight = dxGetFontHeight;
local math_type = math_type;
local math = math;
local math_simple = math_simple;
local math_mul = math_mul;
local tostring = tostring;
local createFormulaLayoutManager = createFormulaLayoutManager;

local MATHDRAW_DEBUG_FONTBOUNDS = false;
local FORMULA_DEBUG_OBJBOUNDS = true;

local drawing_func = false;

local _dxfont_scale_fixer = 5/4;
local _dxfont_scale_fixer_alphanum = 1/3;

local function _dxGetFontHeightFixed(scale, font, texttype)
    if not (texttype) or (texttype == "brackets") then
        return math.ceil(dxGetFontHeight(scale, font) / _dxfont_scale_fixer);
    elseif (texttype == "alphanumeric") then
        local origfh = dxGetFontHeight(scale, font);
        return math.ceil(origfh - origfh * _dxfont_scale_fixer_alphanum);
    end
    
    return false;
end

local function _dxDrawTextFixed(text, l, t, _, __, color, scale, font, texttype)
    local fixoffy;
    
    local origfh = dxGetFontHeight(scale, font);
    
    if not (texttype) or (texttype == "brackets") then
        fixoffy = math.ceil(origfh / 5);
    elseif (texttype == "alphanumeric") then
        fixoffy = math.ceil(origfh / 5);
    else
        return false;
    end

    if (MATHDRAW_DEBUG_FONTBOUNDS) then
        local dbgcolor = tocolor(255, 255, 255, 255);
        local nfh = _dxGetFontHeightFixed(scale, font, texttype);
        local tw = dxGetTextWidth(text, scale, font);
        dxDrawRectangle(l, t, tw, nfh, dbgcolor);
    end

    local fh = dxGetFontHeight(scale, font);
    return dxDrawText( text, l, t - fixoffy, _, __, color, scale, font );
end

addEventHandler("onClientRender", root, function()
        if (drawing_func) then
            drawing_func();
        end
    end
);

-- Globals.
local formula_font = "clear";
local formula_baseScale = 4;
local formula_fontHeight = _dxGetFontHeightFixed(formula_baseScale, formula_font, "alphanumeric");
local formula_fontColor = tocolor(0, 0, 0, 255);
local formula_appropriateLineHeight = math.ceil(1.5 * formula_baseScale);

local function draw_align_mid(w, mw)
    return math.floor(mw/2 - w/2);
end

-- Drawing some shapes that are commonly found in mathematical formulas.
local rootshape_norm_front_w = 40;
local rootshape_norm_border_w = 10;
local rootshape_norm_border_h = 10;
local rootshape_norm_linew = 3;
local rootshape_norm_inside_border_w = 5;
local rootshape_norm_inside_border_h = 5;
local rootshape_norm_back_w = 40;
local rootshape_fontScaleNormal = 2;

local function rootshape_rescale(x, fontScale)
    return math.ceil(x * fontScale / rootshape_fontScaleNormal);
end

local function calculateRootShape(inside_w, inside_h, fontScale)
    local function rescale(x)
        return rootshape_rescale(x, fontScale);
    end
    
    local linew = rootshape_norm_linew;

    local inside_off_x =
        rootshape_norm_border_w
        + rescale(rootshape_norm_front_w)
        + rootshape_norm_border_w;
    
    local width =
        inside_off_x
        + inside_w
        + rootshape_norm_inside_border_w
        + rescale(rootshape_norm_back_w)
        + rootshape_norm_border_w;
        
    local inside_off_y =
        rootshape_norm_border_h
        + rescale(linew)
        + rootshape_norm_inside_border_h;
        
    local height =
        inside_off_y
        + inside_h
        + rootshape_norm_border_h;
        
    return inside_off_x, inside_off_y, width, height;
end

local function drawRootShape(offx, offy, inside_w, inside_h, fontScale)
    local function rescale(x)
        return rootshape_rescale(x, fontScale);
    end
    
    local linew = rootshape_norm_linew;
    
    local draw_rect_start_x = rootshape_norm_border_w + offx;
    local draw_rect_start_y = rootshape_norm_border_h + offy;
    
    local front_box_w = rescale(rootshape_norm_front_w);
    local rootshape_h =
        rescale(linew)
        + rootshape_norm_inside_border_h
        + inside_h;
        
    local content_start_x =
        rescale(rootshape_norm_front_w)
        + rootshape_norm_inside_border_w;
        
    local content_start_y =
        rescale(linew);
    
    local fp_x = math.floor(linew / 2);
    local fp_y = math.ceil(rootshape_h * 0.66);
    
    local sp_x = math.ceil(front_box_w * 0.9);
    local sp_y = math.ceil(rootshape_h - linew / 2);
    
    local tp_x = math.floor(front_box_w - linew / 2);
    local tp_y = math.floor(linew / 2);
    
    local fourthp_x = math.ceil(content_start_x + inside_w + rootshape_norm_inside_border_w + linew / 2);
    local fourthp_y = tp_y;
    
    local backw = rescale(rootshape_norm_back_w);
    
    local fifthp_x = math.ceil(content_start_x + inside_w + backw - linew / 2);
    local fifthp_y = math.ceil(fourthp_y + rootshape_h * 0.25);
    
    local function draw_root_line(sx, sy, ex, ey)
        dxDrawLine(
            draw_rect_start_x + sx, draw_rect_start_y + sy,
            draw_rect_start_x + ex, draw_rect_start_y + ey,
            formula_fontColor, linew
        );
    end
    
    draw_root_line(fp_x, fp_y, sp_x, sp_y);
    draw_root_line(sp_x, sp_y, tp_x, tp_y);
    draw_root_line(tp_x, tp_y, fourthp_x, fourthp_y);
    draw_root_line(fourthp_x, fourthp_y, fifthp_x, fifthp_y);
end

local left_bracket_text = "(";
local right_bracket_text = ")";
local bracket_unitary_height = _dxGetFontHeightFixed(1, formula_font, "brackets");
local leftbracket_unitary_width = dxGetTextWidth(left_bracket_text, 1, formula_font);
local rightbracket_unitary_width = dxGetTextWidth(right_bracket_text, 1, formula_font);
local bracket_divisor_spacing = 2;
local bracket_outer_spacing = 0;

local function calculateBracketShape(inside_w, inside_h)
    local height_scale = math.max( 1, inside_h / bracket_unitary_height );

    local function rescale(x)
        return math.ceil( x * height_scale );
    end    

    local left_box_width
        = rescale(bracket_outer_spacing + leftbracket_unitary_width + bracket_divisor_spacing);
        
    local right_box_width
        = rescale(bracket_divisor_spacing + rightbracket_unitary_width + bracket_outer_spacing);
        
    local box_height
        = rescale(bracket_unitary_height);
    
    return
        left_box_width, 0,
        ( left_box_width + inside_w + right_box_width ), box_height;
end

local function drawBracketShape(draw_x, draw_y, inside_w, inside_h)
    local height_scale = math.max( 1, inside_h / bracket_unitary_height );

    local function rescale(x)
        return math.ceil( x * height_scale );
    end
    
    local left_box_width
        = rescale(bracket_outer_spacing + leftbracket_unitary_width + bracket_divisor_spacing);
        
    local right_box_width
        = rescale(bracket_divisor_spacing + rightbracket_unitary_width + bracket_outer_spacing);
    
    local box_height
        = rescale(bracket_unitary_height);
    
    local inside_align_h = draw_align_mid(inside_h, box_height);
    
    local left_box_x = 0;
    local left_box_y = 0;
    
    local content_x = ( left_box_x + left_box_width );
    local content_y = 0;
    
    local right_box_x = ( content_x + inside_w );
    local right_box_y = 0;

    if (MATHDRAW_DEBUG_FONTBOUNDS) then
        dxDrawRectangle(
            draw_x + left_box_x,
            draw_y + left_box_y,
            left_box_width, box_height,
            tocolor(255, 255, 255, 255)
        );
    end
    _dxDrawTextFixed(
        left_bracket_text,
        draw_x + left_box_x + rescale(bracket_outer_spacing),
        draw_y + left_box_y,
        0, 0, formula_fontColor, height_scale, formula_font, "brackets"
    );
    -- THE CONTENT IS DRAWN BY THE USER.
    if (MATHDRAW_DEBUG_FONTBOUNDS) then
        dxDrawRectangle(
            draw_x + right_box_x,
            draw_y + right_box_y,
            right_box_width, box_height,
            tocolor(255, 255, 255, 255)
        );
    end
    _dxDrawTextFixed(
        right_bracket_text,
        draw_x + right_box_x + rescale(bracket_divisor_spacing),
        draw_y + right_box_y,
        0, 0, formula_fontColor, height_scale, formula_font, "brackets"
    );
end

-- Division drawing parameters.
local div_separator_height = formula_appropriateLineHeight;
local div_separator_border_h = 5;

local function calculateDivisionShape(counter_w, counter_h, divisor_w, divisor_h, font_scale)
    local width = math.max(counter_w, divisor_w);
    local height = ( counter_h + div_separator_border_h + div_separator_height + div_separator_border_h + divisor_h );
    
    local off_counter = draw_align_mid(counter_w, width);
    local off_divisor = draw_align_mid(divisor_w, width);
    
    local cur_draw_y = 0;
    
    local counter_offx = off_counter;
    local counter_offy = cur_draw_y;

    cur_draw_y = cur_draw_y + counter_h;
    cur_draw_y = cur_draw_y + div_separator_border_h;
    
    -- SEPARATOR is drawn by the drawDivisionShape function.
    cur_draw_y = cur_draw_y + div_separator_height;
    
    cur_draw_y = cur_draw_y + div_separator_border_h;

    local div_offx = off_divisor;
    local div_offy = cur_draw_y;

    return counter_offx, counter_offy, div_offx, div_offy, width, height;
end

local function drawDivisionShape(xoff, yoff, counter_w, counter_h, divisor_w, divisor_h, font_scale)
    local width = math.max(counter_w, divisor_w);
    local height = ( counter_h + div_separator_border_h + div_separator_height + div_separator_border_h + divisor_h );

    local off_counter = draw_align_mid(counter_w, width);
    local off_divisor = draw_align_mid(divisor_w, width);
    
    dxDrawRectangle(xoff, yoff + counter_h + div_separator_border_h, width, div_separator_height, formula_fontColor);

    -- counter and divisor are drawn by the user.
end

-- Exponentiation parameters.
local exp_to_main_scale = 1/3;
local exp_distancer = 2;

local function calculateExpShape(main_w, main_h, exp_content_w, exp_content_h)
    local main_h_scaled = ( main_h * exp_to_main_scale );
    
    local exp_scale = ( main_h_scaled / exp_content_h );
    
    local half_exp_h = ( main_h_scaled / 2 );
    
    local exp_offx = ( main_w + exp_distancer );
    local exp_offy = ( -half_exp_h );
    
    local width = ( exp_offx + exp_content_w * exp_scale );
    local height = ( half_exp_h + main_h );
    
    return exp_offx, exp_offy, exp_scale, width, height;
end

-- Global layout manager for formula layouts.
local formula_layout_man = createFormulaLayoutManager();

local function tadditems(t1, t2)
    local t1n = #t1;
    
    for m,n in ipairs(t2) do
        t1[t1n + m] = n;
    end
end

local function get_recursive_deps(node)
    local deps = {};
    
    local function add_recursive_deps(n)
        local curdeps = n.getDependencies();
        
        tadditems(deps, curdeps);
        
        for m,n in ipairs(curdeps) do
            add_recursive_deps(n);
        end
    end
    
    return deps;
end

-- Set up common translations for unknown formulas (pi, e, ...).
local _unknown_remap =
{
    [math.pi] = "\207\128",
    [math.exp(1)] = "e"
};

local function createDrawingFormula(formula)
    local obj = {};
    
    -- Layout node of this drawing formula, for the drawing hierarchy.
    local layout_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, nil, nil, nil);
    
    function obj.getLayoutNode()
        return layout_node;
    end
    
    local function valign_layout_callback(c_xmin, c_xmax, c_ymin, c_ymax)
        local h = ( c_ymax - c_ymin );
        
        return false, -h/2, false, false, false;
    end
    
    -- Determine the size of the drawing.
    local objtype = math_type(formula);
    
    local border_w = 4;
    local border_h = 2;
    
    layout_node.setBorder(border_h, border_w, border_h, border_w);
    
    local function add_boxing_to_node(boxing_node)
        boxing_node.addChildrenCallback(
            function(min_x, max_x, min_y, max_y)
                return -min_x, -min_y, false, false, false;
            end
        );
    end
    
    local function make_fraction_layout(parent_node, counter_node, divisor_node)
        local boxing_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, parent_node, nil, nil, nil);

        local function halign_layout_node(minx, maxx, miny, maxy)
            return -(maxx - minx) / 2, false, false, false, false;
        end
        
        counter_node.setParent(boxing_node);
        counter_node.clearChildrenCallbacks();  -- TODO: hack
        counter_node.addChildrenCallback(halign_layout_node);
        
        local div_adjustment_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, boxing_node, nil, nil, nil);
        
        local div_boxing_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, div_adjustment_node, nil, nil, nil);
        
        add_boxing_to_node(div_boxing_node);
        
        divisor_node.setParent(div_boxing_node);
        div_adjustment_node.addChildrenCallback(halign_layout_node);
        div_adjustment_node.addDependency(
            { counter_node },
            function(minx, maxx, miny, maxy)
                local yoff = ( maxy + div_separator_border_h + div_separator_height + div_separator_border_h );
            
                return false, yoff, false, false, false;
            end
        );

        -- Add a partial dependency on just the counter_draw layout node to calculate the yoff.
        -- We need the dependency of both the counter and the divisor to get the x position as well as the width.
        local separator_node = formula_layout_man.createLayoutNode(false, false, false, div_separator_height, 1, boxing_node,
            { counter_node },
            function(minx, maxx, miny, maxy)
                local yoff = ( maxy + div_separator_border_h );
                
                return false, yoff, false, false, false;
            end
        );
        separator_node.addDependency(
            { counter_node, div_adjustment_node },
            function(minx, maxx, miny, maxy)
                return minx, false, (maxx - minx), false, false;
            end
        );
        
        function separator_node.draw(xoff, yoff, scale)
            local sep_x, sep_y = separator_node.getAbsolutePos();
            local sep_w, sep_h = separator_node.getSize();
            local sep_scale = separator_node.getAbsoluteScale();
            
            sep_y = sep_y + div_separator_height * sep_scale * scale / 2;
            
            dxDrawLine(
                xoff + sep_x * scale, yoff + sep_y,
                xoff + (sep_x + sep_w * sep_scale) * scale, yoff + sep_y,
                formula_fontColor, div_separator_height * sep_scale * scale
            );
        end
        
        return boxing_node;
    end
    
    if (objtype == "disfract") or (objtype == "unknown") then
        local text;
        
        if (objtype == "unknown") then
            text = _unknown_remap[formula];
            
            if not (text) then
                if (type(formula) == "number") then
                    text = "[~" .. tostring(formula) .. "]";
                else
                    text = "[" .. tostring(formula) .. "]";
                end
            end
        else
            text = tostring(formula);
        end
        
        local textWidth = dxGetTextWidth(text, formula_baseScale, formula_font);
    
        function layout_node.draw(xoff, yoff, scale)
            local abs_x, abs_y = layout_node.getAbsolutePos();
            local abs_scale = layout_node.getAbsoluteScale();
        
            xoff = xoff + abs_x;
            yoff = yoff + abs_y;
            scale = scale * abs_scale;
        
            _dxDrawTextFixed(
                text, xoff, yoff, 0, 0,
                formula_fontColor, formula_baseScale * scale, formula_font, "alphanumeric"
            );
        end
        
        layout_node.setInitPos(0, 0);
        layout_node.setInitSize(textWidth, formula_fontHeight);
        layout_node.addChildrenCallback(valign_layout_callback);
    elseif (objtype == "fraction") then
        local counter_draw = createDrawingFormula(formula.getCounter());
        local divisor_draw = createDrawingFormula(formula.getDivisor());
    
        local box_node = make_fraction_layout(layout_node, counter_draw.getLayoutNode(), divisor_draw.getLayoutNode());
    
        add_boxing_to_node(box_node);
    
        layout_node.setInitPos(0, 0);
        layout_node.addChildrenCallback(valign_layout_callback);
    elseif (objtype == "real") then
        -- The monster.
        local summands = formula.getSummands();
        
        -- Calculate drawing meta-data for each summand:
        -- * the drawing offset of each summand
        -- Also span out the bounding box of all the components.
        
        -- The baseline for numerics is the bottom line of all numerics,
        -- for division it is the middle of all numerics.
        
        local function create_node_appender(parent_node)
            local lastobj = false;
            local lastnode = false;
            
            local appender = {};
            
            function appender.append_new_node(node)
                local prevnode;
                
                if (lastobj) then
                    prevnode = lastobj.getLayoutNode();
                elseif (lastnode) then
                    prevnode = lastnode;
                end
                
                if (prevnode) then
                    node.addBorderDependency(
                        { prevnode },
                        function(min_x, max_x, min_y, max_y)
                            return max_x, false, false, false, false;
                        end
                    );
                end
            end
        
            function appender.append_new_formulaobj(childObj, xspacing)
                appender.append_new_node(childObj.getLayoutNode());
                
                lastobj = childObj;
                lastnode = false;
            end
            
            function appender.setLastNode(node)
                lastobj = false;
                lastnode = node;
            end
            
            function appender.setLastObject(obj)
                lastobj = obj;
                lastnode = false;
            end
            
            return appender;
        end
        
        local main_appender = create_node_appender();
        
        local plus_spacing = 4;
        
        for m,n in ipairs(summands) do
            local is_negative = false;
    
            local node_above_divisor = false;
            local node_below_divisor = false;
            
            local node_above_divisor_appender = false;
            local node_below_divisor_appender = false;
            
            local function process_multiplicant(multobj, exp)
                local parent_node = nil;
                local parent_node_appender = nil;
                
                local is_exp_negative = (math_lt(exp, 0) == true);
                
                if (is_exp_negative) then
                    if not (node_below_divisor) then
                        node_below_divisor = formula_layout_man.createLayoutNode(0, 0, false, false, 1, layout_node, nil, nil, nil);
                        node_below_divisor_appender = create_node_appender();
                    end
                    
                    parent_node = node_below_divisor;
                    parent_node_appender = node_below_divisor_appender;
                    
                    exp = math_mul(exp, -1);
                else
                    if not (node_above_divisor) then
                        node_above_divisor = formula_layout_man.createLayoutNode(0, 0, false, false, 1, layout_node, nil, nil, nil);
                        node_above_divisor_appender = create_node_appender();
                    end
                
                    parent_node = node_above_divisor;
                    parent_node_appender = node_above_divisor_appender;
                end
            
                if (exp == 1) and (math_lt(multobj, 0) == true) then
                    is_negative = not is_negative;
                    multobj = math_mul(multobj, -1);
                end
            
                local multobjtype = math_type(multobj);
                local exptype = math_type(exp);
            
                -- Does the formula require a bracket?
                local required_encapsulation = false;
                
                if not (exp == 1) then
                    if (exptype == "fraction") and not (exp.getDivisor() == 1) then
                        required_encapsulation = "rootshape";
                    else
                        if (multobjtype == "fraction") or (multobjtype == "real") then
                            required_encapsulation = "bracket";
                        end
                    end
                end
                
                local multobjformula = createDrawingFormula(multobj);
                local addobj;
                local addobj_node;
                
                if (required_encapsulation == "bracket") then
                    local bracketeer = formula_layout_man.createLayoutNode(0, 0, false, false, 1, parent_node, nil, nil,
                        function(min_x, max_x, min_y, max_y)
                            local xoff, yoff, full_w, full_h = calculateBracketShape(max_x - min_x, max_y - min_y);
                            
                            return false, -full_h / 2, full_w, full_h, false;
                        end
                    );
                    
                    parent_node_appender.append_new_node(bracketeer);
                    
                    local bracket_alignment_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, bracketeer, nil, nil, nil);
                    
                    local boxing_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, bracket_alignment_node, nil, nil, nil);
                    
                    add_boxing_to_node(boxing_node);
                    
                    multobjformula.setParentToLayoutNode(boxing_node);
                    bracket_alignment_node.addChildrenCallback(
                        function(min_x, max_x, min_y, max_y)
                            local xoff, yoff, full_w, full_h = calculateBracketShape(max_x - min_x, max_y - min_y);
                            
                            return xoff, yoff, false, false, false;
                        end
                    );
                    addobj = bracketeer;
                    addobj_node = bracketeer;
                    
                    function bracketeer.draw(xoff, yoff, scale)
                        multobjformula.draw(xoff, yoff, scale);
                        
                        local abs_x, abs_y = bracketeer.getAbsolutePos();
                        local abs_w, abs_h = multobjformula.getSize();
                        local abs_scale = bracketeer.getAbsoluteScale();
                        drawBracketShape(xoff + abs_x, yoff + abs_y, abs_w * abs_scale * scale, abs_h * abs_scale * scale);
                    end
                    
                    parent_node_appender.setLastNode(bracketeer);
                elseif (required_encapsulation == "rootshape") then
                    local rootshaper = formula_layout_man.createLayoutNode(0, 0, false, false, 1, parent_node, nil, nil,
                        function(min_x, max_x, min_y, max_y)
                            local xoff, yoff, full_w, full_h = calculateRootShape(max_x - min_x, max_y - min_y, 2);
                            
                            return false, -full_h / 2, full_w, full_h, false;
                        end
                    );
                    
                    parent_node_appender.append_new_node(rootshaper);
                    
                    local rootshaper_alignment_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, rootshaper, nil, nil, nil);
                    
                    local boxing_node = formula_layout_man.createLayoutNode(false, false, false, false, 1, rootshaper_alignment_node, nil, nil, nil);
                    
                    add_boxing_to_node(boxing_node);
                    
                    multobjformula.setParentToLayoutNode(boxing_node);
                    rootshaper_alignment_node.addChildrenCallback(
                        function(min_x, max_x, min_y, max_y)
                            local xoff, yoff, full_w, full_h = calculateRootShape(max_x - min_x, max_y - min_y, 2);
                            
                            return xoff, yoff, false, false, false;
                        end
                    );
                    addobj = rootshaper;
                    addobj_node = rootshaper;
                    
                    function rootshaper.draw(xoff, yoff, scale)
                        multobjformula.draw(xoff, yoff, scale);
                        
                        local abs_x, abs_y = rootshaper.getAbsolutePos();
                        local abs_w, abs_h = multobjformula.getSize();
                        local abs_scale = rootshaper.getAbsoluteScale();
                        drawRootShape(xoff + abs_x, yoff + abs_y, abs_w * abs_scale * scale, abs_h * abs_scale * scale, 2);
                    end
                    
                    parent_node_appender.setLastNode(rootshaper);
                else
                    multobjformula.setParentToLayoutNode(parent_node);
                    parent_node_appender.append_new_formulaobj(multobjformula, 0);
                    addobj = multobjformula;
                    addobj_node = multobjformula.getLayoutNode();
                end
                
                if not (exp == 1) then
                    local exp_actualFormula;
                    
                    if (required_encapsulation == "rootshape") then
                        exp_actualFormula = exp.getDivisor();
                    else
                        exp_actualFormula = exp;
                    end
                
                    local expobjformula = createDrawingFormula(exp_actualFormula);
                    local expobjformula_layoutNode = expobjformula.getLayoutNode();
                    expobjformula.setParentToLayoutNode(parent_node);
                
                    if (required_encapsulation == "rootshape") then
                        local rootexp_to_main_scale = 1/2;
                
                        expobjformula_layoutNode.addDependency(
                            { addobj_node },
                            function(minx, maxx, miny, maxy)
                                local h = ( maxy - miny );
                                
                                return minx, h * rootexp_to_main_scale, false, false, rootexp_to_main_scale;
                            end
                        );
                    else
                        expobjformula_layoutNode.addBorderDependency(
                            { addobj_node },
                            function(minx, maxx, miny, maxy)
                                local exp_offX = ( maxx + exp_distancer );
                                
                                return exp_offX, miny, false, false, exp_to_main_scale;
                            end
                        );
                    end
                    
                    if not (required_encapsulation) or (required_encapsulation == "bracket") then
                        parent_node_appender.setLastObject(expobjformula);
                    end
                end
            end
            
            -- What is the offset and the bounding box of component n?
            if not (n.numeric == 1) then
                process_multiplicant(n.numeric, 1);
            end
            
            for j,k in ipairs(n.multiplicants) do
                process_multiplicant(k.obj, k.exp);
            end

            if (is_negative) or (m >= 2) then
                -- Add a plus symbol.
                local plus_text;
                
                if (is_negative) then
                    plus_text = "-";
                else
                    plus_text = "+";
                end
                
                local plus_width = dxGetTextWidth(plus_text, formula_baseScale, formula_font);
                local plusnode = formula_layout_man.createLayoutNode(false, false, plus_width + plus_spacing * 2, formula_fontHeight, 1, layout_node, nil, nil, valign_layout_callback);
                
                main_appender.append_new_node(plusnode);
                
                function plusnode.draw(xoff, yoff, scale)
                    local abs_x, abs_y = plusnode.getAbsolutePos();
                    local abs_scale = plusnode.getAbsoluteScale() * scale;
                    
                    abs_x = abs_x + xoff;
                    abs_y = abs_y + yoff;
                    
                    _dxDrawTextFixed(plus_text, abs_x + plus_spacing * abs_scale, abs_y, 0, 0, formula_fontColor, formula_baseScale * abs_scale, formula_font, "alphanumeric");
                end
                
                main_appender.setLastNode(plusnode);
            end
                    
            -- Need to arrange the things.
            local new_node;
            
            if (node_below_divisor) then
                -- Need to display as fraction.
                new_node = formula_layout_man.createLayoutNode(0, 0, false, false, 1, layout_node, nil, nil, valign_layout_callback);
                
                local box_node = make_fraction_layout(new_node, node_above_divisor, node_below_divisor, true);
                add_boxing_to_node(box_node);
            else
                -- Need to display without fraction.
                if (node_above_divisor) then
                    node_above_divisor.setParent(layout_node);
                    new_node = node_above_divisor;
                end
            end
            
            if (new_node) then
                new_node.setBorder(border_w, border_h, border_w, border_h);
            
                main_appender.append_new_node(new_node);
                main_appender.setLastNode(new_node);
            end
        end
        
        layout_node.setInitPos(0, 0);
    else
        -- Need to have a concrete math object.
        return false;
    end
    
    function obj.getSize()
        formula_layout_man.arrangeNode(layout_node);
    
        local minx, maxx, miny, maxy = layout_node.getParentSpaceValues();
        local w = ( maxx - minx );
        local h = ( maxy - miny );
    
        return w, h;
    end
        
    function obj.setParentToNode(parent)
        layout_node.setParent(parent.getLayoutNode());
    end
    
    function obj.setParentToLayoutNode(parent)
        layout_node.setParent(parent);
    end
    
    function obj.draw(xoff, yoff, scale)
        local iterator = createTreeNodeIterator(
            function(node)
                return node.getChildren();
            end,
            function(node)
                return node.getParent();
            end
        );
        
        iterator.setCurrentNode(layout_node);
        
        -- Perform layouting.
        formula_layout_man.arrangeNode(layout_node);
        
        -- Do the drawing.
        while not (iterator.isEnd()) do
            local curNode = iterator.getCurrentNode();
            
            local draw_cb = curNode.draw;
            
            if (draw_cb) then
                draw_cb(xoff, yoff, scale);
            end
            
            iterator.next();
        end
    end
    
    return obj;
end
_G.createDrawingFormula = createDrawingFormula;

-- Tests.
addCommandHandler("dt", function(_, ftype)
        if (ftype == "disfract") then
            local todraw = createDrawingFormula(12345);
        
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "fraction") then
            local todraw = createDrawingFormula(createFraction(42, 103));
            
            drawing_func = function()
                if (FORMULA_DEBUG_OBJBOUNDS) then
                    dxDrawRectangle(300, 300, 10, 10, tocolor(255, 0, 0, 255));
                end
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "tsqrt") then
            local inside_w = 100;
            local inside_h = 100;
            local offx, offy, w, h = calculateRootShape(inside_w, inside_h, 2);
            local rectcolor = tocolor(255, 0, 0, 255);
            
            drawing_func = function()
                drawRootShape(300, 300, inside_w, inside_h, 2);
                dxDrawRectangle(300 + offx, 300 + offy, inside_w, inside_h, rectcolor);
            end
        elseif (ftype == "tbrackets") then
            local small_inside_w = 100;
            local small_inside_h = 20;
            local small_offx, small_offy, small_w, small_h = calculateBracketShape(small_inside_w, small_inside_h);
            local rectcolor = tocolor(255, 0, 0, 255);
            
            local medium_inside_w = 100;
            local medium_inside_h = 60;
            local medium_offx, medium_offy, medium_w, medium_h = calculateBracketShape(medium_inside_w, medium_inside_h);
            
            local big_inside_w = 100;
            local big_inside_h = 120;
            local big_offx, big_offy, big_w, big_h = calculateBracketShape(big_inside_w, big_inside_h);
            
            drawing_func = function()
                drawBracketShape(300, 300, small_inside_w, small_inside_h);
                dxDrawRectangle(300 + small_offx, 300 + small_offy, small_inside_w, small_inside_h, rectcolor);
                
                drawBracketShape(450, 300, medium_inside_w, medium_inside_h);
                dxDrawRectangle(450 + medium_offx, 300 + medium_offy, medium_inside_w, medium_inside_h, rectcolor);
                
                drawBracketShape(700, 300, big_inside_w, big_inside_h);
                dxDrawRectangle(700 + big_offx, 300 + big_offy, big_inside_w, big_inside_h, rectcolor);
            end
        elseif (ftype == "texp") then
            local main_w = 400;
            local main_h = 300;
            local exp_orig_w = 150;
            local exp_orig_h = 100;
            local exp_offx, exp_offy, exp_scale, width, height = calculateExpShape(main_w, main_h, exp_orig_w, exp_orig_h);
            local rectcolor = tocolor(255, 0, 0, 255);
            
            drawing_func = function()
                dxDrawRectangle(300, 300, main_w, main_h, rectcolor);
                dxDrawRectangle(300 + exp_offx, 300 + exp_offy, exp_orig_w * exp_scale, exp_orig_h * exp_scale, rectcolor);
            end
        elseif (ftype == "expfract") then
            local fractobj = createDrawingFormula(createFraction(5, 9));
            local fractobj_w, fractobj_h = fractobj.getSize();
            local fract_in_bracket_offx, fract_in_bracket_offy, fractbracket_w, fractbracket_h = calculateBracketShape(fractobj_w, fractobj_h);
            local expobj = createDrawingFormula(42);
            local exp_orig_w, exp_orig_h = expobj.getSize();
            local exp_offx, exp_offy, exp_scale, width, height = calculateExpShape(fractbracket_w, fractbracket_h, exp_orig_w, exp_orig_h);
            local dbgcolor = tocolor(255, 255, 255, 255);
            
            drawing_func = function()
                drawBracketShape(300, 300, fractobj_w, fractobj_h);
                fractobj.draw(300 + fract_in_bracket_offx, 300 + fract_in_bracket_offy, 1);
                expobj.draw(300 + exp_offx, 300 + exp_offy, exp_scale);
            end
        elseif (ftype == "sqroot") then
            local obj = math_pow(2, createFraction(1, 2));
            local todraw = createDrawingFormula(obj);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdf") then
            local todraw = createDrawingFormula(createRealNumber(13));
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realfract") then
            local todraw = createDrawingFormula(createRealNumber(createFraction(1, 3)));
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realexp") then
            local num = math_pow(createRealNumber(math.pi), 6);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realexpfract") then
            local num = math_pow(createRealNumber(math.pi), createFraction(5, 7));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realrootfract") then
            local num = math_pow(createFraction(2, 3), createFraction(1, 3));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realadd") then
            local num = math_add(createRealNumber(math.pi), createRealNumber(math.exp(1)));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realaddcomplex") then
            local real1 = math_pow(createRealNumber(math.pi), createFraction(1, 4));
            local real2 = math_pow(createRealNumber(math.exp(1)), createFraction(1, 3));
            local num = math_add(real1, real2);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realaddcomplex2") then
            local num = math_pow(math_add(createRealNumber(math.pi), createFraction(1, 2)), 2);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realaddcomplex3") then
            local num = math_pow(math_add(createRealNumber(math.pi), createFraction(1, 3)), createRealNumber(math.exp(1)));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realaddcomplex4") then
            local num = math_pow(math_add(createRealNumber(math.pi), createFraction(1, 2)), createFraction(1, 2));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdiv") then
            local num = math_div(createRealNumber(math.pi), createRealNumber(math.exp(1)));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdivcomplex") then
            local above_divisor = math_add(createRealNumber(math.pi), createRealNumber(math.exp(1)));
            local below_divisor = createRealNumber(math.exp(2));
            local num = math_div(above_divisor, below_divisor);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdivcomplex2") then
            local num = math_add(createRealNumber(math.pi), createFraction(4, 9));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdivcomplex3") then
            local num = math_add(math_mul(createFraction(9, 13), createRealNumber(math.exp(1))), createRealNumber(math.pi));
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdivcomplex4") then
            local above_divisor = math_mul(createRealNumber(math.exp(1)), createFraction(1, 14));
            local below_divisor = math_add(math_mul(createRealNumber(math.pi), createFraction(7, 11)), createRealNumber(math.exp(1)));
            local num = math_div(above_divisor, below_divisor);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "realdivcomplex5") then
            local above_divisor = math_pow(2, createFraction(1, 3));
            local below_divisor = math_pow(3, createFraction(1, 5));
            local num = math_div(above_divisor, below_divisor);
            local todraw = createDrawingFormula(num);
            
            drawing_func = function()
                todraw.draw(300, 300, 1);
            end
        elseif (ftype == "off") then
            drawing_func = false;
        end
        
        outputDebugString("set to " .. ftype);
    end
);