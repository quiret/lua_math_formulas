-- Optimizations.
local createFraction = createFraction;
local createRealNumber = createRealNumber;
local math_add = math_add;
local math_sub = math_sub;
local math_neg = math_neg;
local math_mul = math_mul;
local math_div = math_div;
local math_inv = math_inv;
local math_pow = math_pow;
local math_eq = math_eq;
local math_lt = math_lt;
local math_le = math_le;
local math_type = math_type;
local math_multiplicant_equal = math_multiplicant_equal;
local assert = assert;

-- Test basic things.
do
    local res = math_add(1, 1);
    
    assert(math_type(res) == "disfract");
    assert(res == 2);
end

do
    local res = math_add(1, 0);
    
    assert(math_type(res) == "disfract");
    assert(res == 1);
end

do
    local res = math_add(1, -1);
    
    assert(math_type(res) == "disfract");
    assert(res == 0);
end

do
    local res = createRealNumber(2);
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 2);
    assert(#summands[1].multiplicants == 0);
end

-- Test adding fractions.
do
    local a = createFraction(1, 2);
    local b = createFraction(1, 3);
    
    local res = ( a + b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 5);
    assert(res.getDivisor() == 6);
end

do
    local a = createFraction(-5, 7);
    local b = 10;
    
    local res = ( a + b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 65);
    assert(res.getDivisor() == 7);
end

do
    local a = createFraction(-9, 11);
    local b = -0;
    
    local res = ( b + a );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == -9);
    assert(res.getDivisor() == 11);
end

-- Test adding real numbers.
do
    local a = createRealNumber();
    
    assert(math_type(a) == "real");
    
    local summands = a.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 0);
end

do
    local a = createRealNumber();
    local b = createRealNumber();
    
    local res = ( a + b );
    
    assert(math_type(res) == "disfract");
    assert(res == 0);
end

do
    local a = createRealNumber(2);
    local b = createRealNumber(3);
    
    local res = ( b + a );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 5);
end

do
    local a = createRealNumber(2);
    local b = createFraction(7, 9);
    
    local res = ( a + b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(math_type(summands[1].numeric) == "fraction");
    assert(summands[1].numeric.getCounter() == 25);
    assert(summands[1].numeric.getDivisor() == 9);
end

do
    local a = createRealNumber();
    local b = math.pi;
    
    local res = ( a + b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 2);
    assert(summands[2].numeric == 1);
    assert(#summands[2].multiplicants == 1);
    assert(math_multiplicant_equal(summands[2].multiplicants[1], math.pi));
end

do
    local a = createRealNumber(math.pi);
    
    assert(math_type(a) == "real");
    
    local summands = a.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
end

do
    local a = createRealNumber(math.pi);
    local b = createRealNumber(math.exp(1));
    
    local res = ( a + b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 2);
    assert(#summands[1].multiplicants == 1);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
    assert(#summands[2].multiplicants == 1);
    assert(math_multiplicant_equal(summands[2].multiplicants[1], math.exp(1)));
end

do
    local a = createRealNumber(math.pi);
    
    local res = ( a + a );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 2);
    assert(#summands[1].multiplicants == 1);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
end

-- Test number negation.
do
    local res = math_neg(1);
    
    assert(res == -1);
end

do
    local a = createFraction(1, 8);
    
    local res = math_neg(a);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == -1);
    assert(res.getDivisor() == 8);
end

do
    local a = createRealNumber(math.pi);
    
    local res = math_neg(a);
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == -1);
end

-- Test number multiplication.
do
    local res = math_mul(1, 1);
    
    assert(math_type(res) == "disfract");
    assert(res == 1);
end

do
    local res = math_mul(2, 2);
    
    assert(math_type(res) == "disfract");
    assert(res == 4);
end

do
    local res = math_mul(1, -1);
    
    assert(math_type(res) == "disfract");
    assert(res == -1);
end

do
    local a = createFraction(1, 4);
    local b = -5;
    
    local res = ( a * b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == -5);
    assert(res.getDivisor() == 4);
end

do
    local a = createFraction(0, 10);
    local b = 2;
    
    local res = ( b * a );
    
    assert(math_type(res) == "disfract");
    assert(res == 0);
end

do
    local a = createFraction(2, 7);
    local b = createFraction(6, 10);
    
    local res = ( a * b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 12);
    assert(res.getDivisor() == 70);
end

do
    local a = createRealNumber(math.pi);
    local b = 2;
    
    local res = ( a * b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 2);
    assert(#summands[1].multiplicants == 1);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
end

do
    local a = createRealNumber(math.pi);
    
    local res = ( a * a );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == 2);
end

do
    local a = createRealNumber(math.pi);
    local b = createRealNumber(math.exp(1));
    
    local res = ( a * b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 2);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
    assert(math_multiplicant_equal(summands[1].multiplicants[2], math.exp(1)));
end

do
    local a = ( createRealNumber(math.pi) + createRealNumber(math.exp(1)) );
    local b = ( createRealNumber("t") );
    
    local res = ( a * b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 2);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 2);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
    assert(math_multiplicant_equal(summands[1].multiplicants[2], "t"));
    assert(#summands[2].multiplicants == 2);
    assert(math_multiplicant_equal(summands[2].multiplicants[1], math.exp(1)));
    assert(math_multiplicant_equal(summands[2].multiplicants[2], "t"));
end

do
    local a = createRealNumber(math.pi);
    local b = createFraction(5, 3);
    
    local res = ( b * a );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(math_type(summands[1].numeric) == "fraction");
    assert(summands[1].numeric.getCounter() == 5);
    assert(summands[1].numeric.getDivisor() == 3);
end

do
    local a = ( createRealNumber(math.pi) + createRealNumber(math.exp(1)) );
    local b = ( createRealNumber(math.exp(1)) + createRealNumber(math.pi) );
    
    local res = ( a * b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 3);
    assert(summands[1].numeric == 2);
    assert(#summands[1].multiplicants == 2);
    assert(math_multiplicant_equal(summands[1].multiplicants[1], math.pi));
    assert(math_multiplicant_equal(summands[1].multiplicants[2], math.exp(1)));
    assert(summands[2].numeric == 1);
    assert(#summands[2].multiplicants == 1);
    assert(summands[2].multiplicants[1].obj == math.pi);
    assert(summands[2].multiplicants[1].exp == 2);
    assert(summands[3].numeric == 1);
    assert(summands[3].numeric == 1);
    assert(#summands[3].multiplicants == 1);
    assert(summands[3].multiplicants[1].obj == math.exp(1));
    assert(summands[3].multiplicants[1].exp == 2);
end

-- Test number inversions...
do
    local res = math_inv(2);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 1);
    assert(res.getDivisor() == 2);
end

do
    local a = createFraction(4, 9);
    
    local res = math_inv(a);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 9);
    assert(res.getDivisor() == 4);
end

do
    local a = createRealNumber(7);
    
    local res = math_inv(a);
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(math_type(summands[1].numeric) == "fraction");
    assert(summands[1].numeric.getCounter() == 1);
    assert(summands[1].numeric.getDivisor() == 7);
end

do
    local a = createRealNumber(7);
    
    local res = math_inv(math_inv(a));
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 7);
    assert(#summands[1].multiplicants == 0);
end

do
    local a = createRealNumber(math.pi);
    
    local res = math_inv(a);
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == -1);
end

do
    local a = createRealNumber(math.pi) + createRealNumber(math.exp(1));
    
    local res = math_inv(a);
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].exp == -1);
    
    local multobj = summands[1].multiplicants[1].obj;
    assert(multobj == a);
end

do
    local a = createRealNumber(math.pi) + createRealNumber(math.exp(1));
    
    local res = math_inv(math_inv(a));
    
    assert(res == a);
end

-- Test some number division.
do
    local res = math_div(1, 7);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 1);
    assert(res.getDivisor() == 7);
end

do
    local res = math_div(4, 2);
    
    assert(res == 2);
end

do
    local res = math_div(-1, 8);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == -1);
    assert(res.getDivisor() == 8);
end

do
    local a = createFraction(6, 9);
    local b = createFraction(4, 3);
    
    local res = ( a / b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 18);
    assert(res.getDivisor() == 36);
end

do
    local a = createFraction(11, 3);
    local b = 13;
    
    local res = ( a / b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 11);
    assert(res.getDivisor() == 39);
end

do  
    local a = 4;
    local b = createFraction(9, 2);
    
    local res = ( a / b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 8);
    assert(res.getDivisor() == 9);
end 

do
    local a = createRealNumber(math.pi);
    local b = 3;
    
    local res = ( a / b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(math_type(summands[1].numeric) == "fraction");
    assert(summands[1].numeric.getCounter() == 1);
    assert(summands[1].numeric.getDivisor() == 3);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == 1);
end

-- Test the taking to-the-power-of.
do
    local res = math_pow( 1, 0 );
    
    assert(math_type(res) == "disfract");
    assert(res == 1);
end

do
    local res = math_pow(2, 2);
    
    assert(math_type(res) == "disfract");
    assert(res == 4);
end

do
    local res = math_pow(1, -1);
    
    assert(math_type(res) == "disfract");
    assert(res == 1);
end

do
    local res = math_pow(1, -2);
    
    assert(math_type(res) == "disfract");
    assert(res == 1);
end

do
    local res = math_pow(2, 2);
    
    assert(math_type(res) == "disfract");
    assert(res == 4);
end

do
    local res = math_pow(2, -2);
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 1);
    assert(res.getDivisor() == 4);
end

do
    local a = 2;
    local b = createFraction(1, 4);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == 2);
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 1);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 4);
end

do
    local a = createFraction(1, 4);
    local b = 3;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 1);
    assert(res.getDivisor() == 64);
end

do
    local a = createFraction(5, 11);
    local b = 2;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 25);
    assert(res.getDivisor() == 121);
end

do
    local a = createFraction(2, 3);
    local b = -4;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "fraction");
    assert(res.getCounter() == 81);
    assert(res.getDivisor() == 16);
end

do
    local a = createFraction(2, 9);
    local b = createFraction(-1, 3);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(math_type(summands[1].multiplicants[1].obj) == "fraction");
    assert(summands[1].multiplicants[1].obj.getCounter() == 9);
    assert(summands[1].multiplicants[1].obj.getDivisor() == 2);
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 1);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 3);
end

do
    local a = createRealNumber(2);
    local b = 2;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 4);
    assert(#summands[1].multiplicants == 0);
end

do
    local a = createRealNumber(math.pi);
    local b = 3;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == 3);
end

do
    local a = ( createRealNumber(math.pi) + createRealNumber(math.exp(1)) );
    local b = 2;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 3);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == 2);
    assert(summands[2].numeric == 2);
    assert(#summands[2].multiplicants == 2);
    assert(math_multiplicant_equal(summands[2].multiplicants[1], math.pi));
    assert(math_multiplicant_equal(summands[2].multiplicants[2], math.exp(1)));
    assert(summands[3].numeric == 1);
    assert(#summands[3].multiplicants == 1);
    assert(summands[3].multiplicants[1].obj == math.exp(1));
    assert(summands[3].multiplicants[1].exp == 2);
end

do
    local a = createRealNumber(5);
    local b = createFraction(1, 4);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == 5);
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 1);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 4);
end

do
    local a = createRealNumber(createFraction(4, 7));
    local b = createFraction(2, 7);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(math_type(summands[1].multiplicants[1].obj) == "fraction");
    assert(summands[1].multiplicants[1].obj.getCounter() == 16);
    assert(summands[1].multiplicants[1].obj.getDivisor() == 49);
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 1);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 7);
end

do
    local a = createRealNumber(math.pi);
    local b = -2;
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == -2);
end

do
    local a = createRealNumber(math.pi);
    local b = createFraction(2, 5);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 2);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 5);
end

do
    local a = createRealNumber(math.pi) + createRealNumber(math.exp(1));
    local b = createFraction(1, 3);
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(math_type(summands[1].multiplicants[1].obj) == "real");
    local subreal = summands[1].multiplicants[1].obj;
    local subsummands = subreal.getSummands();
    assert(#subsummands == 2);
    assert(subsummands[1].numeric == 1);
    assert(#subsummands[1].multiplicants == 1);
    assert(math_multiplicant_equal(subsummands[1].multiplicants[1], math.pi));
    assert(subsummands[2].numeric == 1);
    assert(#subsummands[2].multiplicants == 1);
    assert(math_multiplicant_equal(subsummands[2].multiplicants[1], math.exp(1)));
    assert(math_type(summands[1].multiplicants[1].exp) == "fraction");
    assert(summands[1].multiplicants[1].exp.getCounter() == 1);
    assert(summands[1].multiplicants[1].exp.getDivisor() == 3);
end

do
    local a = createRealNumber(math.pi);
    local b = createRealNumber(math.exp(1));
    
    local res = ( a ^ b );
    
    assert(math_type(res) == "real");
    
    local summands = res.getSummands();
    assert(#summands == 1);
    assert(summands[1].numeric == 1);
    assert(#summands[1].multiplicants == 1);
    assert(summands[1].multiplicants[1].obj == math.pi);
    assert(summands[1].multiplicants[1].exp == b);
end

-- Test equality.
do
    assert( math_eq(1, 1) );
    assert( not math_eq(1, 0) );
    assert( not math_eq(1, -1) );
    assert( math_eq(1, createFraction(1, 1)) );
    assert( math_eq(2, createFraction(2, 1)) );
    assert( math_eq(1, createFraction(99, 99)) );
    assert( math_eq(0, createFraction(0, 1)) );
    assert( math_eq(-1, createFraction(1, -1)) );
    assert( math_eq(createFraction(14, 28), createFraction(1, 2)) );
    assert( math_eq(createRealNumber(1), 1) );
    assert( math_eq(createRealNumber(createFraction(3, 5)), createFraction(6, 10)) );
    assert( math_eq(createRealNumber(math.pi), createRealNumber(math.pi)) );
    assert( not math_eq(createRealNumber(math.pi), createRealNumber(math.exp(1))) );
    assert( not math_eq(createFraction(1, 3), createFraction(1, 2)) );
    assert( not math_eq(1, createFraction(1, 2)) );
end

-- Test less-than.
do
    assert( not (math_lt(1, 1)) );
    assert( math_lt(1, 2) );
    assert( math_lt(-5, -2) );
    assert( math_lt(1, createFraction(3, 2)) );
    assert( math_lt(createFraction(4, 3), 2) );
    assert( math_lt(createFraction(99, 100), createFraction(50, 20)) );
    assert( math_lt(1, createRealNumber(math.pi)) );
    assert( math_lt(3, createRealNumber(math.pi)) );
    assert( not (math_lt(5, createRealNumber(math.pi))) );
    assert( math_lt(createRealNumber(math.pi), 5) );
    assert( math_lt(createRealNumber(math.exp(1)), createRealNumber(math.pi)) );
end

-- Test less-than-or-equal.
do
    assert( math_le(1, 1) );
    assert( math_le(-1, 1) );
    assert( not (math_le(3, 2)) );
    assert( math_le(createFraction(4, 3), createFraction(7, 3)) );
    assert( math_le(0, createFraction(1, 999)) );
    assert( math_le(createFraction(1, 999999), 999999) );
    assert( math_le(createRealNumber(math.pi), createRealNumber(math.pi)) );
end