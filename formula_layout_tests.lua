-- Optimizations.
local createFormulaLayoutManager = createFormulaLayoutManager;
local assert = assert;

-- Test some basic layouts and their associated math.

-- Basic Example #1
do
    local manager = createFormulaLayoutManager("Basic Example #1");
    
    local mf = manager.createLayoutNode(100, 100, false, false, 1, nil, nil, nil);
    local sw1 = manager.createLayoutNode(50, 50, 150, 150, 1, mf, nil, nil);
    local sw2 = manager.createLayoutNode(250, 250, 100, 100, 0.5, mf, nil, nil);
    
    manager.arrangeLayout();
    
    local mf_minx, mf_maxx, mf_miny, mf_maxy = mf.getValues();
    
    assert(mf_minx == 150);
    assert(mf_maxx == 400);
    assert(mf_miny == 150);
    assert(mf_maxy == 400);
end

-- Basic Example #2
do
    local manager = createFormulaLayoutManager("Basic Example #2");
    
    local m = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil);
    local s1 = manager.createLayoutNode(50, 75, false, false, 0.5, m, nil, nil);
    local s2 = manager.createLayoutNode(30, 40, 100, 100, 0.5, s1, nil, nil);
    
    manager.arrangeLayout();
    
    local m_minx, m_maxx, m_miny, m_maxy = m.getValues();
    
    assert(not (m_minx == false));
    assert(m_minx == 65);
    assert(m_maxx == 90);
    assert(m_miny == 95);
    assert(m_maxy == 120);
end

-- Basic Example #3
do
    local manager = createFormulaLayoutManager("Basic Example #3");
    
    local sc = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil);
    local w1 = manager.createLayoutNode(50, 50, 200, 150, 1, sc, nil, nil);
    local w2 = manager.createLayoutNode(300, 50, 150, 300, 1, sc, nil, nil);
    local tb1 = manager.createLayoutNode(25, 25, 150, 100, 1, w1, nil, nil);
    local b1 = manager.createLayoutNode(15, 130, 80, 15, 1, w1, nil, nil);
    local b2 = manager.createLayoutNode(105, 130, 80, 15, 1, w1, nil, nil);
    local L1 = manager.createLayoutNode(25, 25, 100, 250, 1, w2, nil, nil);
    local b3 = manager.createLayoutNode(35, 280, 80, 15, 1, w2, nil, nil);
    
    manager.arrangeLayout();
    
    local sc_minx, sc_maxx, sc_miny, sc_maxy = sc.getValues();
    
    assert(sc_minx == 50);
    assert(sc_maxx == 450);
    assert(sc_miny == 50);
    assert(sc_maxy == 350);
end

-- Advanced Example #1: Functional Dependency
do
    local manager = createFormulaLayoutManager("Advanced Example #1");
    
    local sc = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil);
    local bx1 = manager.createLayoutNode(20, 20, 100, 100, 1, sc, nil, nil);
    local bx2 = manager.createLayoutNode(20, 140, 100, 50, 1, sc, nil, nil);
    local bx3 = manager.createLayoutNode(false, false, 60, 60, 1, sc, {bx1, bx2},
        function(minx, maxx, miny, maxy)
            return maxx + 10, (maxy + miny) / 2 - 30, false, false, false;
        end
    );
    
    manager.arrangeLayout();
    
    local sc_minx, sc_maxx, sc_miny, sc_maxy = sc.getValues();
    assert(sc_minx == 20);
    assert(sc_maxx == 190);
    assert(sc_miny == 20);
    assert(sc_maxy == 190);
end

-- GC test.
do
    local manager = createFormulaLayoutManager("GC Test");
    
    local node = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil);
    
    assert(manager.getNumNodes() == 1);
    assert(manager.getNumMathClouds() == 1);
    
    collectgarbage("collect");
    
    assert(manager.getNumNodes() == 1);
    assert(manager.getNumMathClouds() == 1);
    
    node = nil;
    
    collectgarbage("collect");
    
    assert(manager.getNumNodes() == 0);
    assert(manager.getNumMathClouds() == 0);
end

-- Advanced Example #2: Alignment on the baseline
do
    local manager = createFormulaLayoutManager("Advanced Example #2");
    
    local mf = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil, nil);
    local sf1 = manager.createLayoutNode(0, false, false, false, 1, mf, nil, nil,
        function(minx, maxx, miny, maxy)
            return false, -( maxy - miny ) / 2, false, false, false;
        end
    );
    local so1 = manager.createLayoutNode(0, 0, 50, 50, 1, sf1, nil, nil, nil);
    local so2 = manager.createLayoutNode(50, 50, 80, 80, 1, sf1, nil, nil, nil);
    local sf2 = manager.createLayoutNode(false, -10, 20, 20, 1, mf, { sf1 },
        function(minx, maxx, miny, maxy)
            return maxx + 10, false, false, false, false;
        end
    );
    
    manager.arrangeLayout();
    
    local minx, maxx, miny, maxy = mf.getValues();
    assert(not not (minx));
    assert(minx == 0);
    assert(maxx == 160);
    assert(miny == -65);
    assert(maxy == 65);
end

-- Advanced Example #3: Stacked baseline alignment
do
    local manager = createFormulaLayoutManager("Advanced Example #3: Stacked baseline alignment");
    
    local function baseline_center_y_cb(minx, maxx, miny, maxy)
        return false, -(maxy - miny) / 2, false, false, false;
    end
    
    local mf = manager.createLayoutNode(0, 0, false, false, 1, nil, nil, nil, nil);
    local sf1 = manager.createLayoutNode(0, false, false, false, 1, mf, nil, nil, baseline_center_y_cb);
    local so1 = manager.createLayoutNode(0, 0, 20, 100, 1, sf1, nil, nil, baseline_center_y_cb);
    local so2 = manager.createLayoutNode(30, 0, 20, 70, 1, sf1, nil, nil, baseline_center_y_cb);
    local so3 = manager.createLayoutNode(50, 0, 20, 120, 1, sf1, nil, nil, baseline_center_y_cb);
    
    manager.arrangeLayout();
    
    local minx, maxx, miny, maxy = mf.getValues();
    assert(not not (minx));
    assert(minx == 0);
    assert(maxx == 70);
    assert(miny == -120);
    assert(maxy == 0);
end