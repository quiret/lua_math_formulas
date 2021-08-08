-- Optimizations.
local _G = _G;
local type = type;
local setmetatable = setmetatable;
local getmetatable = getmetatable;
local tostring = tostring;
local math = math;
local table = table;
local rawequal = rawequal;
local ipairs = ipairs;
local pairs = pairs;
local assert = assert;

-- We want to create a symbolic formula-calculation utility because using hardware numbers results in
-- fast but inaccurate approximations: the next best thing is writing a utility where numbers are symbols.
-- This module is not about performance and should not be ported to fast languages; it exists purely for 
-- scientific calculatory reasons.

-- TODO: remove redundancies related to real numbers that turn zero, fractions that turn zero, etc (in math ops they should simplify).

local do_math_debug = false;

function math_debug(set_debug)
    if (set_debug) then
        do_math_debug = true;
    else
        do_math_debug = false;
    end
end

local function isFormulaObject(obj)
    local objtype = type(obj);
    
    if not (objtype == "table") then return false; end;
    
    local mt = getmetatable(obj);
    
    return not not (mt);
end

-- Checks if a number is passed which does not have a fractional part.
-- This includes all natural numbers but also negative numbers and the zero.
local function is_disfract_number(obj)
    local objtype = type(obj);
    
    if not (objtype == "number") then return false; end;
    
    local whole = math.modf(obj);
    
    if not (obj == whole) then return false; end;
    
    return true;
end

-- Since we handle natural numbers, negative numbers and the zero using the Lua internal representation, we do not need
-- a special object for them. But we have the need for fractional numbers as well as irrational numbers.

-- Helper metatable for easier typing.
local _fo_mt_helper = {};

local function get_number_type(a)
    local atype = type(a);
    
    if (atype == "table") then
        if (getmetatable(a) == _fo_mt_helper) then
            return a.getType();
        end
    elseif (is_disfract_number(a)) then
        return "disfract";
    end
    
    return "unknown";
end
_G.math_type = get_number_type;

local createFraction;

local function optimizedFraction(a, b)
    local remainder = ( a % b );
    
    if (remainder == 0) then
        return ( a / b );
    else
        return createFraction(a, b);
    end
end

-- a/b
function createFraction(a, b)
    local obj = {};
    
    assert(is_disfract_number(a) and is_disfract_number(b));
    assert(not (b == 0), "attempt to divide by zero");
    
    if (b < 0) then
        -- Make sure that the divisor is always 0 or a positive number.
        a = -a;
        b = -b;
    end
    
    function obj.getType()
        return "fraction";
    end
    
    function obj.getCounter()
        return a;
    end
    
    function obj.getDivisor()
        return b;
    end
    
    function obj.negate()
        return optimizedFraction( -a, b );
    end
    
    function obj.tostring()
        return a .. " / " .. b;
    end
    
    setmetatable(obj, _fo_mt_helper);
    
    return obj;
end
_G.createFraction = createFraction;

local function createRealNumberSummand()
    local sum = {};
    sum.numeric = 1;
    sum.multiplicants = {};
    return sum;
end

local function createRealNumberMultiplicant(obj)
    local mult = {};
    mult.obj = obj;
    mult.exp = 1;
    return mult;
end

local function cloneRealNumberSingleMultiplicant(mult)
    local new = {};
    new.obj = mult.obj;
    new.exp = mult.exp;
    return new;
end

local function cloneRealNumberMultiplicants(multiplicants)
    local new = {};
    
    for m,n in ipairs(multiplicants) do
        new[m] = cloneRealNumberSingleMultiplicant(n);
    end
    
    return new;
end

local function is_multiplicant(a)
    local atype = type(a);
    
    if not (atype == "table") then return false; end;
    
    if (a.exp == nil) then return false; end;
    
    return true;
end

local function findMultiplicantByBase(multiplicants, base)
    for m,n in ipairs(multiplicants) do
        if (n.obj == base) then
            return n;
        end
    end
    
    return false;
end

local function removeMultiplicant(multiplicants, mult)
    for m,n in ipairs(multiplicants) do
        if (n == mult) then
            table.remove(multiplicants, m);
            break;
        end
    end
end

local multiplyRealNumberMultiplicants;

local function multiplyRealNumberSingleMultiplicant(summand, item, new_exp)
    if (new_exp == nil) then
        new_exp = 1;
    end

    -- TODO: fix fix fix fix.
    
    local item_type = get_number_type(item);

    if (new_exp == 1) and ((item_type == "fraction") or (item_type == "disfract")) then
        summand.numeric = ( summand.numeric * item );
    else
        local multiplicants = summand.multiplicants; 

        local found = findMultiplicantByBase(multiplicants, item);
        
        if (found) then
            found.exp = ( found.exp + new_exp );
            
            if (found.exp == 0) then
                removeMultiplicant(multiplicants, found);
            elseif (found.exp == 1) then
                -- If is any other multiplicant with exp = 1 then multiply the contents
                -- together.
                local multobj = found.obj;
                local did_multi = false;
                local n = 1;
                local num_multi = #multiplicants;
                
                while ( n <= num_multi ) do
                    local cur_multi = multiplicants[ n ];
                    
                    if (cur_multi.exp == 1) and not (cur_multi == found) then
                        multobj = ( multobj * cur_multi.obj );
                        did_multi = true;
                        table.remove(multiplicants, curmulti);
                        num_multi = num_multi - 1;
                    else
                        n = n + 1;
                    end
                end
                
                if (did_multi) then
                    removeMultiplicant(multiplicants, found);
                    
                    -- Insert the freshly multiplied object again.
                    multiplyRealNumberSingleMultiplicant(summand, multobj);
                end
            end
        else
            -- Check if we can unpack the number (in case it is a real number).
            if (item_type == "real") and (#item.getSummands() == 1) then
                local sub_summand = item.getSummands()[1];
                multiplyRealNumberSingleMultiplicant(summand, sub_summand.numeric, new_exp);
                
                for m,n in ipairs(sub_summand.multiplicants) do
                    local num_exp = ( n.exp * new_exp );
                    multiplyRealNumberSingleMultiplicant(summand, n.obj, num_exp);
                end
            else
                local new_entry = createRealNumberMultiplicant(item);
                new_entry.exp = new_exp;
                table.insert(summand.multiplicants, new_entry);
            end
        end
    end
end

-- TODO: this function is flawed, fix it because it does not take simplifications.
-- into account.
function multiplyRealNumberMultiplicants(a, b)
    for m,n in ipairs(b) do
        local found = findMultiplicantByBase(a, n.obj);
        
        if (found) then
            found.exp = found.exp + n.exp;
        else
            table.insert(a, cloneRealNumberSingleMultiplicant(n));
        end
    end
end

local function powRealNumberMultiplicants(multiplicants, pow)
    local new = cloneRealNumberMultiplicants(multiplicants);
    
    for m,n in ipairs(new) do
        n.exp = ( n.exp * pow );
    end
    
    return new;
end

local function compareRealNumberMultiplicant(a, b)
    local left_is_multi = is_multiplicant(a);
    local right_is_multi = is_multiplicant(b);
    
    if (left_is_multi) and (right_is_multi) then
        if not (a.obj == b.obj) then
            return false;
        end
        
        if not (a.exp == b.exp) then
            return false;
        end
    
        return true;
    elseif (left_is_multi) or (right_is_multi) then
        local multi, other;
        
        if (left_is_multi) then
            multi = a;
            other = b;
        else
            multi = b;
            other = a;
        end
        
        if not (multi.obj == other) then return false; end;
        if not (multi.exp == 1) then return false; end;
        
        return true;
    end
    
    return false;
end
_G.math_multiplicant_equal = compareRealNumberMultiplicant;

local function cloneRealNumberSingleSummand(summand)
    local newitem = {};
    newitem.numeric = summand.numeric;
    newitem.multiplicants = cloneRealNumberMultiplicants(summand.multiplicants);
    return newitem;
end

local function cloneRealNumberSummands(summands)
    local new = {};
    
    for m,n in ipairs(summands) do
        new[m] = cloneRealNumberSingleSummand(n);
    end
    
    return new;
end

local function removeSummand(summands, item)
    for m,n in ipairs(summands) do
        if (n == item) then
            table.remove(summands, m);
            break;
        end
    end
end

local function equalMultiplicants(a, b)
    local function has_multi_entry(mults, item)
        for m,n in ipairs(mults) do
            if (compareRealNumberMultiplicant(n, item)) then
                return true;
            end
        end
        
        return false;
    end
    
    if not (#a == #b) then return false; end;
    
    for j,k in ipairs(b) do
        if not (has_multi_entry(a, k)) then
            return false;
        end
    end
    
    return true;
end

local function findCompatibleSummandToMultiplicants(summands, find_multiplicants)    
    for m,n in ipairs(summands) do
        local s_ms = n.multiplicants;
        
        if (equalMultiplicants(s_ms, find_multiplicants)) then
            return n;
        end
    end
    
    return false;
end

function createRealNumber(summand)
    local obj = {};
    local summands = {};
    
    function obj.getType()
        return "real";
    end
    
    function obj.setSummands(newsumms)
        summands = newsumms;
    end
    
    function obj.setSingleSummand(summand)
        summands = { summand };
    end
    
    function obj.getSummands()
        return summands;
    end

    function obj.clone()
        local cloned = createRealNumber();
        cloned.setSummands(cloneRealNumberSummands(summands));
        return cloned;
    end
    
    function obj.tostring()
        local res = "";
        local has_summand = false;
        
        for m,n in ipairs(summands) do
            if (has_summand) then
                res = res .. " + ";
            end
        
            res = res .. tostring(n.numeric) .. "*(?real?)";
            
            has_summand = true;
        end
    
        return res;
    end
    
    if not (summand == nil) then
        local stype = get_number_type(summand);
        
        if (stype == "disfract") or (stype == "fraction") then
            local new = createRealNumberSummand();
            new.numeric = summand;
            table.insert(summands, new);
        elseif not (summand == false) then
            local new = createRealNumberSummand();
            table.insert(new.multiplicants, createRealNumberMultiplicant(summand));
            table.insert(summands, new);
        end
    else
        local new = createRealNumberSummand();
        new.numeric = 0;
        table.insert(summands, new);
    end
    
    setmetatable(obj, _fo_mt_helper);
    
    return obj;
end

local function add_numbers(a, b, is_sub)
    local atype = get_number_type(a);
    local btype = get_number_type(b);

    if (atype == "disfract") and (btype == "disfract") then
        if (is_sub) then
            return ( a - b );
        else
            return ( a + b );
        end
    elseif
        ((atype == "disfract") and (btype == "fraction")) or
        ((atype == "fraction") and (btype == "disfract")) then
        
        local disfract, fraction;
        
        if (atype == "disfract") then
            disfract = a;
            fraction = b;
        else
            disfract = b;
            fraction = a;
        end
        
        local fraction_counter = fraction.getCounter();
        local fraction_divisor = fraction.getDivisor();
        
        if (is_sub) then
            return optimizedFraction( fraction_counter - disfract * fraction_divisor, fraction_divisor );
        else
            return optimizedFraction( fraction_counter + disfract * fraction_divisor, fraction_divisor );
        end
    elseif (atype == "fraction") and (btype == "fraction") then
        local a_counter = a.getCounter();
        local a_divisor = a.getDivisor();
        local b_counter = b.getCounter();
        local b_divisor = b.getDivisor();
        
        if (is_sub) then
            return optimizedFraction( a_counter * b_divisor - b_counter * a_divisor, a_divisor * b_divisor );
        else
            return optimizedFraction( a_counter * b_divisor + b_counter * a_divisor, a_divisor * b_divisor );
        end
    elseif (atype == "real") or (btype == "real") then
        local real, other;
        local othertype;
    
        if (atype == "real") then
            real = a;
            other = b;
            othertype = btype;
        else
            real = b;
            other = a;
            othertype = atype;
        end
        
        -- The real number consists of a sum of possible symbolic numbers, like pi or e.
        -- There is at max one fraction or disfract number.
        -- Due to their internal complexity, real numbers are mutable (and clonable).
        local new_a = a.clone();
        
        if (othertype == "real") then
            local a_summands = new_a.getSummands();
            local b_summands = b.getSummands();
            
            for m,n in ipairs(b_summands) do
                local found = findCompatibleSummandToMultiplicants(a_summands, n.multiplicants);
                
                if (found) then
                    found.numeric = add_numbers(found.numeric, n.numeric);
                    
                    if (found.numeric == 0) then
                        removeSummand(a_summands, found);
                    end
                else
                    -- Add a new member of the sum.
                    table.insert(a_summands, cloneRealNumberSingleSummand(n));
                end
            end
            
            if (#a_summands == 0) then
                return 0;
            end
        elseif (othertype == "fraction") or (othertype == "disfract") then
            local a_summands = new_a.getSummands();
            local has_modified_existing = false;
            
            for m,n in ipairs(a_summands) do
                if (#n.multiplicants == 0) then
                    n.numeric = add_numbers(n.numeric, other);
                    
                    if (n.numeric == 0) then
                        removeSummand(a_summands, n);
                    end
                    
                    has_modified_existing = true;
                    break;
                end
            end
            
            if (#a_summands == 0) then
                return 0;
            end
            
            if (has_modified_existing == false) then
                local summ = createRealNumberSummand();
                summ.numeric = other;
                table.insert(a_summands, summ);
            end
        else
            local a_summands = new_a.getSummands();
            local has_adjusted_numeric = false;
            
            for m,n in ipairs(a_summands) do
                local multiplicants = n.multiplicants;
                
                if (#multiplicants == 1) and (compareRealNumberMultiplicant(multiplicants[1].obj, other)) then
                    n.numeric = add_numbers(n.numeric, 1);
                    
                    if (n.numeric == 0) then
                        removeSummand(a_summands, n);
                    end
                    
                    has_adjusted_numeric = true;
                    break;
                end
            end
            
            if (#a_summands == 0) then
                return 0;
            end
        
            if (has_adjusted_numeric == false) then
                -- We add the thing as a symbol.
                local summ = createRealNumberSummand();
                table.insert(summ.multiplicants, createRealNumberMultiplicant(other));
                table.insert(a_summands, summ);
            end
        end
        
        return new_a;
    end
    
    return false;
end
_G.math_add = add_numbers;

local function sub_numbers(a, b)
    return add_numbers(a, b, true);
end
_G.math_sub = sub_numbers;

local function neg_number(a)
    local atype = get_number_type(a);
    
    if (atype == "disfract") then
        return -a;
    elseif (atype == "fraction") then
        local counter = a.getCounter();
        local divisor = a.getDivisor();
        
        return optimizedFraction(-counter, divisor);
    elseif (atype == "real") then
        -- Just negate all the numerics of the summands.
        local new = a.clone();
        
        local summands = new.getSummands();
        
        for m,n in ipairs(summands) do
            n.numeric = -n.numeric;
        end
        
        return new;
    end
    
    return false;
end
_G.math_neg = neg_number;

local function mul_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);

    if (atype == "disfract") and (btype == "disfract") then
        return ( a * b );
    elseif
        ((atype == "fraction") and (btype == "disfract")) or
        ((atype == "disfract") and (btype == "fraction")) then
        
        local fraction, other;
        
        if (atype == "fraction") then
            fraction = a;
            other = b;
        else
            fraction = b;
            other = a;
        end
        
        if (other == 1) then
            return fraction;
        end
        
        local fraction_counter = fraction.getCounter();
        local fraction_divisor = fraction.getDivisor();
        
        return optimizedFraction( fraction_counter * other, fraction_divisor );
    elseif (atype == "fraction") and (btype == "fraction") then
        local a_counter = a.getCounter();
        local a_divisor = a.getDivisor();
        local b_counter = b.getCounter();
        local b_divisor = b.getDivisor();
        
        return optimizedFraction( a_counter * b_counter, a_divisor * b_divisor );
    elseif (atype == "real") or (btype == "real") then
        local real, other, othertype;
        
        if (atype == "real") then
            real = a;
            other = b;
            othertype = btype;
        else
            real = b;
            other = a;
            othertype = atype;
        end
        
        if (othertype == "real") then
            local new_real = createRealNumber(false);
        
            -- We allow real numbers to be multiplicants in real number summands so this is how things could stack...
            local real_summands = real.getSummands();
            local other_summands = other.getSummands();
            
            local newreal_summands = new_real.getSummands();
            
            for m,n in ipairs(real_summands) do
                for j,k in ipairs(other_summands) do
                    local multiplied = cloneRealNumberMultiplicants(n.multiplicants);
                    multiplyRealNumberMultiplicants(multiplied, k.multiplicants);
                    local new_numeric = ( n.numeric * k.numeric );
                    
                    if not (new_numeric == 0) then
                        local found = findCompatibleSummandToMultiplicants(newreal_summands, multiplied);
                        
                        if (found) then
                            found.numeric = ( found.numeric + new_numeric );
                            
                            if (found.numeric == 0) then
                                removeSummand(newreal_summands, found);
                            end
                        else
                            local new_sum = createRealNumberSummand();
                            new_sum.numeric = new_numeric;
                            new_sum.multiplicants = multiplied;
                            table.insert(newreal_summands, new_sum);
                        end
                    end
                end
            end
            
            if (#newreal_summands == 0) then
                return 0;
            end
            
            return new_real;
        elseif (othertype == "disfract") or (othertype == "fraction") then
            if (other == 1) then
                return real;
            elseif (other == 0) then
                return 0;
            end
        
            local new_real = real.clone();
            
            local real_summands = new_real.getSummands();
            
            local n = 1;
            local num_summands = #real_summands;
            
            while ( n <= num_summands ) do
                local item = real_summands[n];
            
                item.numeric = ( item.numeric * other );
                
                if (item.numeric == 0) then
                    table.remove(real_summands, n);
                    num_summands = num_summands - 1;
                else
                    n = n + 1;
                end
            end
            
            if (num_summands == 0) then
                return 0;
            end
            
            return new_real;
        else
            -- We just multiply this new multiplicant to each summand.
            local new_real = real.clone();
            
            local newreal_summands = new_real.getSummands();
            
            local n = 1;
            local num_summands = #newreal_summands;
            
            while ( n <= num_summands ) do
                local item = newreal_summands[n];
            
                multiplyRealNumberSingleMultiplicant(item, other);
                
                if (item.numeric == 0) then
                    table.remove(newreal_summands, n);
                    num_summands = num_summands - 1;
                else
                    n = n + 1;
                end
            end
            
            if (num_summands == 0) then
                return 0;
            end
            
            return new_real;
        end
    end
    
    return false;
end
_G.math_mul = mul_numbers;

local function inv_number(a)
    local atype = get_number_type(a);
    
    if (atype == "disfract") then
        return optimizedFraction(1, a);
    elseif (atype == "fraction") then
        local counter = a.getCounter();
        local divisor = a.getDivisor();
        
        return optimizedFraction( divisor, counter );
    elseif (atype == "real") then
        -- We create a new real number where the first summand contains an inverted multiplicant.
        -- Or if it is already like that, we extract the real number.
        local summands = a.getSummands();
        
        if (#summands == 1) then
            local orig_summand = summands[1];
            
            -- Is it just a packed real number?
            local orig_multiplicants = orig_summand.multiplicants;
            
            local function is_packed_multiplicant_real(x)
                if not (get_number_type(x.obj) == "real") then return false; end;
                
                if not (x.exp == -1) then return false; end;
                
                return true;
            end
            
            if (#orig_multiplicants == 1) and (is_packed_multiplicant_real(orig_multiplicants[1])) then
                -- Unpack it.
                return orig_multiplicants[1].obj;
            else
                local new_a = createRealNumber(false);
                local summand = createRealNumberSummand();
                summand.numeric = inv_number(orig_summand.numeric);
                summand.multiplicants = powRealNumberMultiplicants(orig_multiplicants, -1);
                table.insert(new_a.getSummands(), summand);
                
                return new_a;
            end
        else
            -- Pack some huge sum of stuff.
            local new_a = createRealNumber(false);
            
            local summand = createRealNumberSummand();
            summand.numeric = 1;
            
            local multi = createRealNumberMultiplicant();
            multi.obj = a;
            multi.exp = -1;
            
            table.insert(summand.multiplicants, multi);
            new_a.setSingleSummand(summand);
            
            return new_a;
        end
    else
        -- We create a new real number that is a division...
        local new_real = createRealNumber(false);
        
        local summand = createRealNumberSummand();
        summand.numeric = 1;
        
        local multiplicant = createRealNumberMultiplicant();
        multiplicant.obj = a;
        multiplicant.exp = -1;
        
        table.insert(summand.multiplicants, multiplicant);
        new_real.setSingleSummand(summand);
        
        return new_real;
    end
    
    return false;
end
_G.math_inv = inv_number;

local function div_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);
    
    if (atype == "disfract") and (btype == "disfract") then
        local remainder = ( a % b );
        
        if (remainder == 0) then
            return ( a / b );
        else
            return createFraction(a, b);
        end
    elseif
        ((atype == "disfract") and (btype == "fraction")) or
        ((atype == "fraction") and (btype == "disfract")) then
        
        local left_counter, left_divisor;
        local right_counter, right_divisor;
        
        if (atype == "fraction") then
            left_counter = a.getCounter();
            left_divisor = a.getDivisor();
            right_counter = 1;
            right_divisor = b;
        else
            left_counter = a;
            left_divisor = 1;
            right_counter = b.getDivisor();
            right_divisor = b.getCounter();
        end
        
        return optimizedFraction( left_counter * right_counter, left_divisor * right_divisor );
    elseif (atype == "fraction") and (btype == "fraction") then
        local a_counter = a.getCounter();
        local a_divisor = a.getDivisor();
        local b_counter = b.getDivisor();
        local b_divisor = b.getCounter();
        
        return optimizedFraction( a_counter * b_counter, a_divisor * b_divisor );
    elseif (atype == "real") or (btype == "real") then
        -- We can invert the real number and then multiply with that inversion.
        -- Pretty complicated shit!
        return mul_numbers(a, inv_number(b));
    end
    
    return false;
end
_G.math_div = div_numbers;

local function pow_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);

    if (atype == "disfract") and (btype == "disfract") then
        if (b >= 0) then
            return ( a ^ b );
        else
            local divisor = a ^ (-b);
            
            return optimizedFraction(1, divisor);
        end
    elseif (atype == "fraction") and (btype == "disfract") then
        local counter = a.getCounter();
        local divisor = a.getDivisor();
        
        if (b >= 0) then
            return optimizedFraction(counter ^ b, divisor ^ b);
        else
            return optimizedFraction(divisor ^ (-b), counter ^ (-b));
        end
    elseif (atype == "disfract") and (btype == "fraction") then
        -- We take square, cubed, ... by the counter; we take squareroot, cubicroot, ... by the divisor.
        local b_counter = b.getCounter();
        local b_divisor = b.getDivisor();
        
        local inter_counter;
        
        if (b_counter >= 0) then
            inter_counter = ( a ^ b_counter );
        else
            inter_counter = optimizedFraction(1, a ^ (-b_counter));
        end
        
        if (b_divisor == 1) then
            return inter_counter;
        elseif (inter_counter == 1) then
            return 1;
        else
            -- Need to take the n-root of the value, thus we return a real number.
            local real = createRealNumber(false);
            
            local summand = createRealNumberSummand();
            summand.numeric = 1;
            
            local multiplicant = createRealNumberMultiplicant(inter_counter);
            multiplicant.exp = createFraction(1, b_divisor);
            
            table.insert(summand.multiplicants, multiplicant);
            real.setSingleSummand(summand);
            
            return real;
        end
    elseif (atype == "fraction") and (btype == "fraction") then
        local a_counter = a.getCounter();
        local a_divisor = a.getDivisor();
        local b_counter = b.getCounter();
        local b_divisor = b.getDivisor();
        
        local inter_value;
        
        if (b_counter >= 0) then
            inter_value = optimizedFraction(a_counter ^ b_counter, a_divisor ^ b_counter);
        else
            inter_value = optimizedFraction(a_divisor ^ (-b_counter), a_counter ^ (-b_counter));
        end
        
        if (b_divisor == 1) then
            return inter_value;
        else
            local real = createRealNumber(false);
            
            local multiplicant = createRealNumberMultiplicant(inter_value);
            multiplicant.exp = createFraction(1, b_divisor);
            
            local summand = createRealNumberSummand();
            summand.numeric = 1;
            table.insert(summand.multiplicants, multiplicant);
            
            real.setSingleSummand(summand);
            
            return real;
        end
    elseif (atype == "real") then
        -- The most complicated case.
        -- We need to add optimizations here.
        local summands = a.getSummands();
        
        if (#summands == 1) then
            -- We just pow every component and multiply the components together.
            local summand = summands[1];
            
            local new_real = createRealNumber(false);
            
            local new_summand = createRealNumberSummand();
            
            local new_numeric = pow_numbers(summand.numeric, b);
            multiplyRealNumberSingleMultiplicant(new_summand, new_numeric);
            
            local orig_multiplicants = summand.multiplicants;
            
            for m,n in ipairs(orig_multiplicants) do
                local new_exp = mul_numbers(n.exp, b);
                local mult = pow_numbers(n.obj, new_exp);
                multiplyRealNumberSingleMultiplicant(new_summand, mult);
            end
            
            new_real.setSingleSummand(new_summand);
            
            return new_real;
        else
            -- At certain pows we can simply multiply by the amount of those times.
            if (btype == "disfract") then
                local is_inv;
                local mult_times;
                
                if (b >= 0) then
                    is_inv = false;
                    mult_times = b;
                else
                    is_inv = true;
                    mult_times = -b;
                end
                
                if (mult_times == 0) then
                    return 1;
                end
                
                local res = a;
                
                for n=2,b do
                    res = mul_numbers(res, a);
                end
                
                if (is_inv) then
                    res = inv_number(res);
                end
                
                return res;
            elseif (btype == "fraction") then
                local is_inv;
                local mult_times;
                
                local b_counter = b.getCounter();
                local b_divisor = b.getDivisor();
                
                if (b_counter >= 0) then
                    is_inv = false;
                    mult_times = b_counter;
                else
                    is_inv = true;
                    mult_times = -b_counter;
                end
                
                if (mult_times == 0) then
                    return 1;
                end
                
                local res = a;
                
                for n=2,mult_times do
                    res = mul_numbers(res, a);
                end
                
                if (is_inv) then
                    res = inv_number(res);
                end
                
                if (b_divisor == 1) then
                    return res;
                end
                
                local new_real = createRealNumber(false);
                
                local summand = createRealNumberSummand();
                
                local multiplicant = createRealNumberMultiplicant(res);
                multiplicant.exp = createFraction(1, b_divisor);
                
                table.insert(summand.multiplicants, multiplicant);
                
                new_real.setSingleSummand(summand);
                
                return new_real;
            else
                -- No idea what to do here, just create a statement.
                local new_real = createRealNumber(false);
                
                local summand = createRealNumberSummand();
                
                local multiplicant = createRealNumberMultiplicant(a);
                multiplicant.exp = b;
                
                table.insert(summand.multiplicants, multiplicant);
                new_real.setSingleSummand(summand);
                
                return new_real;
            end
        end
    else
        if (a == 1) then
            return 1;
        end
    
        -- Just construct a new pow.
        local new_real = createRealNumber(false);
        
        local summand = createRealNumberSummand();
        
        local multiplicant = createRealNumberMultiplicant(a);
        multiplicant.exp = b;
        
        table.insert(summand.multiplicants, multiplicant);
        new_real.setSingleSummand(summand);
        
        return new_real;
    end
    
    return false;
end
_G.math_pow = pow_numbers;

local function eq_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);
    
    if (atype == "real") or (btype == "real") then
        local real, other, othertype;
        
        if (atype == "real") then
            real = a;
            other = b;
            othertype = btype;
        else
            real = b;
            other = a;
            othertype = atype;
        end
        
        if (othertype == "real") then
            local function find_summand(summands, item)
                for m,n in ipairs(summands) do
                    if
                        (n.numeric == item.numeric) and
                        (equalMultiplicants(n.multiplicants, item.multiplicants)) then
                        
                        return n;
                    end
                end
                
                return false;
            end
            
            local real_summands = real.getSummands();
            local other_summands = other.getSummands();
            
            if not (#real_summands == #other_summands) then return false; end;
            
            for m,n in ipairs(real_summands) do
                if not (find_summand(other_summands, n)) then
                    return false;
                end
            end
            
            return true;
        else
            local summands = real.getSummands();
            
            if not (#summands == 1) then return false; end;
            
            local summand = summands[1];
            
            if (othertype == "fraction") or (othertype == "disfract") then
                if not (#summand.multiplicants == 0) then return false; end
                
                return (summand.numeric == other);
            else
                if not (#summand.multiplicants == 1) then return false; end;
                
                return compareRealNumberMultiplicant(summand.multiplicants[1], other);
            end
        end
    elseif (atype == "fraction") or (btype == "fraction") then
        local fraction, other, othertype;
        
        if (atype == "fraction") then
            fraction = a;
            other = b;
            othertype = btype;
        else
            fraction = b;
            other = a;
            othertype = atype;
        end
        
        if (othertype == "fraction") then
            return ( fraction.getCounter() * other.getDivisor() == fraction.getDivisor() * other.getCounter() );
        elseif (othertype == "disfract") then
            return ( fraction.getDivisor() * other == fraction.getCounter() );
        end
    elseif (atype == "disfract") or (btype == "disfract") then
        return rawequal(a, b);
    end
    
    return rawequal(a, b);
end
_G.math_eq = eq_numbers;

-- Internal function, because we are not supposed to use approximate stuff.
-- But just doing it for... leniance. Should be improved by mathematical proofs
-- instead but not for now.
local function approximate_num(num)
    local numtype = get_number_type(num);
    
    if (numtype == "disfract") then
        return num;
    elseif (numtype == "fraction") then
        return ( num.getCounter() / num.getDivisor() );
    elseif (numtype == "real") then
        local value = 0;
        
        for m,n in ipairs(num.getSummands()) do
            local mult = approximate_num(n.numeric);
            
            for m,n in ipairs(n.multiplicants) do
                local baseval = approximate_num(n.obj);
                local expval = approximate_num(n.exp);
                
                if not (baseval) or not (expval) then
                    return false;
                end
                
                mult = mult * ( baseval ^ expval );
            end
            
            value = value + mult;
        end
        
        return value;
    else
        local luatype = type(num);
        
        if (luatype == "number") then
            return num;
        end
    end
    
    return false;
end

local function lt_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);
    
    if (atype == "disfract") and (btype == "disfract") then
        return ( a < b );
    elseif (atype == "disfract") and (btype == "fraction") then
        return ( a * b.getDivisor() < b.getCounter() );
    elseif (atype == "fraction") and (btype == "disfract") then
        return ( a.getCounter() < b * a.getDivisor() );
    elseif (atype == "fraction") and (btype == "fraction") then
        return ( a.getCounter() * b.getDivisor() < a.getDivisor() * b.getCounter() );
    elseif (atype == "real") or (btype == "real") then
        local approx_a = approximate_num(a);
        local approx_b = approximate_num(b);
        
        if not (approx_a) or not (approx_b) then
            return "unknown";
        end
    
        return ( approx_a < approx_b );
    end
    
    return "unknown";
end
_G.math_lt = lt_numbers;

local function le_numbers(a, b)
    local atype = get_number_type(a);
    local btype = get_number_type(b);
    
    if (atype == "disfract") and (btype == "disfract") then
        return ( a <= b );
    elseif (atype == "disfract") and (btype == "fraction") then
        return ( a * b.getDivisor() <= b.getCounter() );
    elseif (atype == "fraction") and (btype == "disfract") then
        return ( a.getCounter() <= b * a.getDivisor() );
    elseif (atype == "fraction") and (btype == "fraction") then
        return ( a.getCounter() * b.getDivisor() <= a.getDivisor() * b.getCounter() );
    elseif (atype == "real") or (btype == "real") then
        local approx_a = approximate_num(a);
        local approx_b = approximate_num(b);
        
        if not (approx_a) or not (approx_b) then
            return "unknown";
        end
    
        return ( approx_a <= approx_b );
    end
    
    return "unknown";
end
_G.math_le = le_numbers;

local function get_simplified_object(obj)
    local objtype = get_number_type(obj);
    
    if (objtype == "real") then
        local summands = obj.getSummands();
        
        if (#summands == 1) then
            local one_summand = summands[1];
            
            local multiplicants = one_summand.multiplicants;
            
            if (#multiplicants == 0) then
                return one_summand.numeric;
            elseif (one_summand.numeric == 1) then
                if (#multiplicants == 1) then
                    local mult = multiplicants[1];
                    
                    if (mult.exp == 1) then
                        return get_simplified_object(mult.obj);
                    end
                end
            end
        end
    end
    
    return obj;
end
_G.math_simple = get_simplified_object;

function _fo_mt_helper.__add(a, b)
    return add_numbers(a, b);
end

function _fo_mt_helper.__sub(a, b)
    return sub_numbers(a, b);
end

function _fo_mt_helper.__unm(a)
    return neg_number(a);
end

function _fo_mt_helper.__mul(a, b)
    return mul_numbers(a, b);
end

function _fo_mt_helper.__div(a, b)
    return div_numbers(a, b);
end

function _fo_mt_helper.__pow(a, b)
    return pow_numbers(a, b);
end

function _fo_mt_helper.__tostring(a)
    return a.tostring();
end

function _fo_mt_helper.__eq(a, b)
    return eq_numbers(a, b);
end

function _fo_mt_helper.__lt(a, b)
    return lt_numbers(a, b);
end

function _fo_mt_helper.__le(a, b)
    return le_numbers(a, b);
end