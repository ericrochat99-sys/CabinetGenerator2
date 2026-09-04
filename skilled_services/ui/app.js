            function $(id){ return document.getElementById(id); }

            const EMBED_DEFAULTS_JSON = {{EMBED_DEFAULTS_JSON}};
            const EMBEDDED_CATALOG_FALLBACK = [{"code":"B12","name":"Base 12","category":"Base","cabinet_type":"Base","default_width":12,"default_height":34.5,"default_depth":24,"minimum_width":9,"maximum_width":21,"width_increment":3,"door_count":1,"drawer_count":1,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Single-door base"},{"code":"B24","name":"Base 24","category":"Base","cabinet_type":"Base","default_width":24,"default_height":34.5,"default_depth":24,"minimum_width":24,"maximum_width":36,"width_increment":3,"door_count":2,"drawer_count":1,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Standard base cabinet"},{"code":"B36","name":"Base 36","category":"Base","cabinet_type":"Base","default_width":36,"default_height":34.5,"default_depth":24,"minimum_width":36,"maximum_width":48,"width_increment":3,"door_count":2,"drawer_count":1,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Wide base cabinet"},{"code":"DB24","name":"Drawer Base 24","category":"Base","cabinet_type":"Base","default_width":24,"default_height":34.5,"default_depth":24,"minimum_width":12,"maximum_width":36,"width_increment":3,"door_count":0,"drawer_count":3,"shelf_count":0,"toe_kick":4,"construction_type":"Project Default","notes":"Three-drawer base"},{"code":"W3018","name":"Wall 30 High x 18 Wide","category":"Wall","cabinet_type":"Wall","default_width":18,"default_height":30,"default_depth":12,"minimum_width":9,"maximum_width":24,"width_increment":3,"door_count":1,"drawer_count":0,"shelf_count":2,"toe_kick":0,"construction_type":"Project Default","notes":"Standard 30-inch-high wall cabinet"},{"code":"W3030","name":"Wall 30 High x 30 Wide","category":"Wall","cabinet_type":"Wall","default_width":30,"default_height":30,"default_depth":12,"minimum_width":24,"maximum_width":36,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":2,"toe_kick":0,"construction_type":"Project Default","notes":"Double-door wall cabinet"},{"code":"W3642","name":"Wall 36 High x 42 Wide","category":"Wall","cabinet_type":"Wall","default_width":42,"default_height":36,"default_depth":12,"minimum_width":36,"maximum_width":48,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":3,"toe_kick":0,"construction_type":"Project Default","notes":"Wide wall cabinet"},{"code":"T2484","name":"Tall Utility 24 x 84","category":"Tall","cabinet_type":"Tall","default_width":24,"default_height":84,"default_depth":24,"minimum_width":18,"maximum_width":36,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":5,"toe_kick":4,"construction_type":"Project Default","notes":"Full-height utility cabinet"},{"code":"P2484","name":"Tall Pantry","category":"Pantry","cabinet_type":"Tall","default_width":24,"default_height":84,"default_depth":24,"minimum_width":18,"maximum_width":36,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":5,"toe_kick":4,"construction_type":"Project Default","notes":"Standard pantry"},{"code":"SB30","name":"Sink Base 30","category":"Sink","cabinet_type":"Sink Base","default_width":30,"default_height":34.5,"default_depth":24,"minimum_width":24,"maximum_width":48,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":0,"toe_kick":4,"construction_type":"Project Default","notes":"False-front sink base"},{"code":"10580","name":"ADA Wall Sink Cabinet","category":"Wall Cabinets","cabinet_type":"ADA Sink","default_width":36,"default_height":32,"default_depth":24,"minimum_width":30,"maximum_width":48,"width_increment":1,"allowed_depths":[24,29],"allowed_material_thicknesses":[0.5,0.625,0.75],"door_count":0,"drawer_count":0,"shelf_count":0,"toe_kick":0,"construction_type":"Frameless","front_rail_height":5,"mount_rail_height":4,"access_panel_type":"Magnetic","notes":"Wall-mounted ADA lavatory cabinet with open top, bottom, and back; removable access panel"},{"code":"V24","name":"Vanity 24","category":"Vanity","cabinet_type":"Base","default_width":24,"default_height":34.5,"default_depth":21,"minimum_width":18,"maximum_width":48,"width_increment":3,"door_count":2,"drawer_count":0,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Standard vanity base"},{"code":"BCB36","name":"Pie-Cut Corner Base","category":"Corner","cabinet_type":"Pie-Cut Corner Base","default_width":36,"default_height":34.5,"default_depth":36,"minimum_width":36,"maximum_width":36,"width_increment":1,"door_count":1,"drawer_count":0,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"36 x 36 pie-cut corner"},{"code":"BDC36","name":"Diagonal Corner Base","category":"Corner","cabinet_type":"Diagonal Corner Base","default_width":36,"default_height":34.5,"default_depth":36,"minimum_width":36,"maximum_width":36,"width_increment":1,"door_count":1,"drawer_count":0,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Diagonal-front corner"},{"code":"BBC42","name":"Blind Corner Base","category":"Corner","cabinet_type":"Blind Corner Base","default_width":42,"default_height":34.5,"default_depth":24,"minimum_width":39,"maximum_width":48,"width_increment":3,"door_count":1,"drawer_count":0,"shelf_count":1,"toe_kick":4,"construction_type":"Project Default","notes":"Blind corner base"},{"code":"TC15","name":"Trash Pull-Out 15","category":"Accessories","cabinet_type":"Trash Can","default_width":15,"default_height":34.5,"default_depth":24,"minimum_width":15,"maximum_width":24,"width_increment":3,"door_count":0,"drawer_count":1,"shelf_count":0,"toe_kick":4,"construction_type":"Project Default","notes":"Full-height pull-out front"},{"code":"CUB24","name":"Cubbies 24","category":"Accessories","cabinet_type":"Cubbies","default_width":24,"default_height":48,"default_depth":24,"minimum_width":12,"maximum_width":48,"width_increment":3,"door_count":0,"drawer_count":0,"shelf_count":3,"toe_kick":4,"construction_type":"Project Default","notes":"Open cubby storage"}];

            let EDIT_TARGET_PID = null;
            let CATALOG = [];
            let CATALOG_MODE = "all";

            function storedList(key){
              try { return JSON.parse(localStorage.getItem(key) || "[]"); } catch(_e) { return []; }
            }

            function catalogMatches(){
              const query = ($("catalog_search")?.value || "").trim().toLowerCase();
              const category = $("catalog_category")?.value || "";
              const favorites = storedList("cabinet_favorites");
              const recent = storedList("cabinet_recent");
              return CATALOG.filter(item => {
                if (category && item.category !== category) return false;
                if (query && !`${item.code} ${item.name} ${item.notes}`.toLowerCase().includes(query)) return false;
                if (CATALOG_MODE === "favorites" && !favorites.includes(item.code)) return false;
                if (CATALOG_MODE === "recent" && !recent.includes(item.code)) return false;
                return true;
              }).sort((a, b) => {
                if (CATALOG_MODE !== "recent") return a.code.localeCompare(b.code);
                return recent.indexOf(a.code) - recent.indexOf(b.code);
              });
            }

            function renderCatalog(keepCode){
              const select = $("catalog_model");
              if (!select) return;
              const items = catalogMatches();
              select.innerHTML = "";
              items.forEach(item => {
                const option = document.createElement("option");
                option.value = item.code;
                option.textContent = `${item.code} — ${item.name}`;
                select.appendChild(option);
              });
              if (keepCode && items.some(item => item.code === keepCode)) select.value = keepCode;
              updateCatalogDetails();
            }

            function updateCatalogDetails(){
              const code = $("catalog_model")?.value;
              const item = CATALOG.find(candidate => candidate.code === code);
              if ($("catalog_notes")) $("catalog_notes").textContent = item ? item.notes : "No cabinets match this filter.";
              const favorites = storedList("cabinet_favorites");
              if ($("toggle_favorite")) $("toggle_favorite").textContent = favorites.includes(code) ? "★ Favorited" : "☆ Favorite";
            }

            function chooseCatalogModel(code, requestDefaults = true){
              const item = CATALOG.find(candidate => candidate.code === code);
              if (!item) return;
              $("catalog_code").value = item.code;
              const recent = storedList("cabinet_recent").filter(value => value !== item.code);
              recent.unshift(item.code);
              try { localStorage.setItem("cabinet_recent", JSON.stringify(recent.slice(0, 10))); } catch(_e) {}
              updateCatalogDetails();
              if (requestDefaults && window.sketchup && sketchup.load_model) sketchup.load_model(item.code);
            }

            function set_catalog_selection(code){
              const item = CATALOG.find(candidate => candidate.code === code);
              if (!item) return;
              $("catalog_category").value = item.category;
              renderCatalog(code);
              $("catalog_model").value = code;
              $("catalog_code").value = code;
              updateCatalogDetails();
            }

            function initialize_catalog(items, lastCode){
              CATALOG = Array.isArray(items) ? items : [];
              const category = $("catalog_category");
              category.innerHTML = '<option value="">All Categories</option>';
              [...new Set(CATALOG.map(item => item.category))].sort().forEach(value => {
                const option = document.createElement("option"); option.value = value; option.textContent = value; category.appendChild(option);
              });
              const selected = CATALOG.find(item => item.code === lastCode) || CATALOG[0];
              // Populate the picker without replacing the ready-to-place type
              // defaults. A catalog model is applied only after the user selects it.
              if (selected) { category.value = selected.category; renderCatalog(selected.code); chooseCatalogModel(selected.code, false); }
            }

            window.initialize_catalog = initialize_catalog;
            window.set_catalog_selection = set_catalog_selection;

            function setEditMode(pid, label){
              const p = parseInt(pid, 10);
              EDIT_TARGET_PID = (p && p > 0) ? p : null;

              const banner = $("edit_banner");
              if (banner) {
                banner.style.display = "block";
                banner.textContent = `Editing selected cabinet: ${label || "Selection"}`;
              }

              if ($("cancel_edit")) $("cancel_edit").style.display = "inline-block";
              if ($("place_new")) $("place_new").style.display = "none";
              if ($("apply_edit")) $("apply_edit").style.display = "inline-block";
            }

            function clearEditMode(){
              EDIT_TARGET_PID = null;

              const banner = $("edit_banner");
              if (banner) banner.style.display = "none";

              if ($("cancel_edit")) $("cancel_edit").style.display = "none";
              if ($("apply_edit")) $("apply_edit").style.display = "none";
              if ($("place_new")) $("place_new").style.display = "inline-block";
            }

            function clear_edit_mode(){ clearEditMode(); }

            function load_selected_cabinet(data, pid, label){
              // Called from Ruby: fills form and switches to in-place edit mode.
              set_form(data);
              setEditMode(pid, label);
              drawPreview();
            }

            const heightPresets = {
              "Base": [34.5],
              "Wall": [30, 36, 42],
              "Tall": [84, 90, 96],
              "Sink Base": [34.5],
              "ADA Sink": [32],
              "Cubbies": [24, 30, 36, 42, 48, 60, 72, 84, 90]
            };

            let lastRevealEdge = 0.0625;

            function fmtNum(n){
              const x = parseFloat(n);
              if (Number.isNaN(x)) return "";
              return (Math.round(x * 1000) / 1000).toString();
            }

            function num(id, fallback){
              const v = parseFloat($(id).value);
              return Number.isFinite(v) ? v : fallback;
            }

            function intNum(id, fallback){
              const v = parseInt($(id).value, 10);
              return Number.isFinite(v) ? v : fallback;
            }

            function doorSplitCountForWidth(w){
              const width = parseFloat(w);
              if (Number.isNaN(width)) return 1;
              return (width >= num("automatic_double_door_threshold_in", 24)) ? 2 : 1;
            }

            function drawerSplitCountForWidth(w){
              const width = parseFloat(w);
              if (Number.isNaN(width)) return 1;
              return (width >= num("automatic_drawer_bank_split_threshold_in", 37)) ? 2 : 1;
            }

            // Mirror Ruby-side `cabinet_has_toe?` rules so the UI preview matches geometry.
            function typeAllowsToeKick(type){
              const t = (type || "").toString();
              if (!t) return false;
              const lower = t.toLowerCase();
              if (lower.includes("wall")) return false;
              if (t === "ADA Sink") return false;
              return (t === "Base" || t === "Tall" || t === "Sink Base" || t === "Trash Can" ||
                t === "Cubbies" || t === "Diagonal Corner Base" || t === "Pie-Cut Corner Base" ||
                t === "Blind Corner Base");
            }

            function populateHeightPresets(type){
              const presets = heightPresets[type] || [];
              const sel = $("height_preset");
              sel.innerHTML = "";
              const opt0 = document.createElement("option");
              opt0.textContent = "(custom)";
              opt0.value = "";
              sel.appendChild(opt0);

              presets.forEach(v => {
                const o = document.createElement("option");
                o.textContent = v.toString();
                o.value = v.toString();
                sel.appendChild(o);
              });
            }

            function setPresetFromHeight(type){
              const presets = new Set((heightPresets[type] || []).map(x => x.toString()));
              const h = ($("height_in").value || "").toString();
              $("height_preset").value = presets.has(h) ? h : "";
            }

            function setOverlayMode(mode){
              const edge = $("reveal_edge_in");
              const isTrue = (mode === "True Full Overlay");
              if (isTrue) {
                const current = parseFloat(edge.value);
                if (Number.isFinite(current) && current > 0) lastRevealEdge = current;
                edge.value = 0;
                edge.disabled = true;
              } else {
                edge.disabled = false;
                const current = parseFloat(edge.value);
                if (!Number.isFinite(current) || current === 0) {
                  edge.value = (Number.isFinite(lastRevealEdge) && lastRevealEdge >= 0) ? lastRevealEdge : 0.0625;
                }
              }
            }

            function applyTopModeRulesForType(type){
              const topMode = $("top_mode");
              const stretcher = $("stretcher_width_in");
              const lockFullTop = (type === "Wall" || type === "Tall" ||
                type === "Diagonal Corner Base" || type === "Pie-Cut Corner Base" ||
                type === "Blind Corner Base");
              if (lockFullTop) {
                topMode.value = "Full Top";
                topMode.disabled = true;
                stretcher.disabled = true;
              } else {
                topMode.disabled = false;
                stretcher.disabled = (topMode.value !== "Stretchers");
              }
            }

            function applyTypeRules(){
              const type = $("cabinet_type").value;

              const isBase = (type === "Base");
              const isTrash = (type === "Trash Can");
              const isSink = (type === "Sink Base" || type === "ADA Sink");
              const isADA = (type === "ADA Sink");
              const isCubbies = (type === "Cubbies");
              const isCorner = (type === "Diagonal Corner Base" ||
                type === "Pie-Cut Corner Base" || type === "Blind Corner Base");

              if (type === "Diagonal Corner Base" || type === "Pie-Cut Corner Base") {
                $("width_in").value = "36";
                $("depth_in").value = "36";
              } else if (type === "Blind Corner Base") {
                $("width_in").value = "42";
                $("depth_in").value = "24";
              }
              $("width_in").disabled = isCorner;
              $("depth_in").disabled = isCorner;
              const sinkSection = $("sink_ada_section");
              if (sinkSection) {
                const show = (isSink || isADA);
                sinkSection.style.display = show ? "block" : "none";
                if (!show) sinkSection.removeAttribute("open");
              }

              
              $("drawer_count").disabled = !isBase;
              $("use_slides").disabled = !(isBase || isTrash);
              $("drawer_front_height_in").disabled = !isBase;

              // Cubbies: Tall cabinet carcass, no doors/drawers; shelves+partitions are auto-computed
              const cubbyRow = $("cubby_target_row");
              if (cubbyRow) cubbyRow.style.display = isCubbies ? "flex" : "none";

              if (isCubbies) {
                $("show_doors").checked = false;
                $("show_doors").disabled = true;
                $("hinge_side").disabled = true;
                $("door_swing").disabled = true;
                $("drawer_count").value = "0";
                $("drawer_count").disabled = true;
                $("partition_count").disabled = true;
                $("shelf_count").disabled = true;
                // Ensure toe kick defaults for cubbies
                if ((parseFloat($("toe_height_in").value) || 0) <= 0) $("toe_height_in").value = 4.0;
                if ((parseFloat($("toe_recess_in").value) || 0) <= 0) $("toe_recess_in").value = 3.0;
                updateCubbiesAuto();
              } else {
                $("show_doors").disabled = false;
                $("hinge_side").disabled = false;
                $("door_swing").disabled = false;
                $("partition_count").disabled = false;
                $("shelf_count").disabled = false;
              }

              $("drawer_gap_in").disabled = !isBase;

              if (!isBase && !isTrash) {
                $("drawer_count").value = "0";
                $("use_slides").checked = false;
              }
              if (isTrash) {
                $("drawer_count").value = "1";
                $("use_slides").checked = true;
              }

              ["false_front_height_in","countertop_thk_in"]
                .forEach(id => { if ($(id)) $(id).disabled = !isSink || isADA; });
              ["ada_knee_clear_h_in","front_rail_height_in","mount_rail_height_in","access_panel_type","fastener_type","mounting_type","second_mount_rail","safety_tether"]
                .forEach(id => { if ($(id)) $(id).disabled = !isADA; });

              // Toe-kick controls: only allowed for certain cabinet types.
              // This is strictly a UI/preview rule; Ruby-side geometry enforces the same.
              const toeAllowed = typeAllowsToeKick(type);
              $("toe_height_in").disabled = !toeAllowed;
              $("toe_recess_in").disabled = !toeAllowed;

              if (!toeAllowed) {
                $("toe_height_in").value = 0;
                $("toe_recess_in").value = 0;
              }
              updateShelfRules();

            }

            function enforceMaxWidth(){
              const w = parseFloat($("width_in").value);
              if (!Number.isNaN(w) && w > 48) $("width_in").value = 48;
            }

function updateDoorCount(){
  const item = CATALOG.find(candidate => candidate.code === ($("catalog_code")?.value || ""));
  $("door_count").value = (item ? item.door_count : doorSplitCountForWidth($("width_in").value)).toString();
}

function computeDrawerUsableInches(){
  const type = $("cabinet_type").value;
  const H = parseFloat($("height_in").value) || 0;
  const toeH = parseFloat($("toe_height_in").value) || 0;
  const drawerGap = parseFloat($("drawer_gap_in").value) || 0;

  const overlayMode = $("overlay_mode").value;
  const revealEdge = (overlayMode === "True Full Overlay") ? 0 : (parseFloat($("reveal_edge_in").value) || 0);

  const isSink = (type === "Sink Base" || type === "ADA Sink");
  const ct = 0;
  const cabinetTop = H - ct;

  return (cabinetTop - toeH - 2*revealEdge);
}

// Drawer front heights are stored as a CSV string (inches), ordered top-to-bottom.
// We support either:
// - N values (preferred): user explicitly controls each drawer height.
// - N-1 values (legacy): last drawer is auto-filled.
function parseDrawerHeightsFromHidden(dc){
  const raw = ($("drawer_front_heights_in") ? ($("drawer_front_heights_in").value || "") : "").trim();
  if (!raw) return [];
  const toks = raw.split(/[;,\s]+/).map(s => (s || "").trim()).filter(Boolean);
  const vals = toks.map(t => parseFloat(t)).filter(v => Number.isFinite(v) && v > 0);
  return vals.slice(0, Math.max(0, dc));
}

// Track which per-drawer fields the user has explicitly changed.
let drawerFrontDirty = [];
let drawerFrontBaseline = [];

function syncDrawerFrontHeightsHidden(){
  const t = $("cabinet_type").value;
  const dc = parseInt($("drawer_count").value || "0", 10) || 0;
  if (t !== "Base" || dc < 2) return;

  const wrap = $("drawer_front_panels");
  const hidden = $("drawer_front_heights_in");
  if (!wrap || !hidden) return;

  const vals = [];
  for (let i = 1; i <= dc; i++){
    const el = document.getElementById(`drawer_front_h_${i}`);
    if (!el) continue;
    const v = parseFloat(el.value);
    if (Number.isFinite(v) && v > 0) vals.push(v);
  }
  hidden.value = vals.join(", ");
}

function rebuildDrawerFrontPanels(){
  const t = $("cabinet_type").value;
  const isBase = (t === "Base");
  const dc = parseInt($("drawer_count").value || "0", 10) || 0;

  const rowTop = $("drawer_front_height_row");
  const rowPanels = $("drawer_front_panels_row");

  if (rowTop) rowTop.style.display = (isBase && dc === 1) ? "block" : "none";
  if (rowPanels) rowPanels.style.display = (isBase && dc >= 2) ? "block" : "none";

  // Keep the legacy hidden field from being edited directly
  if ($("drawer_front_heights_in")) $("drawer_front_heights_in").disabled = true;

  const wrap = $("drawer_front_panels");
  if (!wrap) return;

  wrap.innerHTML = "";
  if (!(isBase && dc >= 2)) return;

  const usableNet = computeDrawerUsableInches() - ((parseFloat($("drawer_gap_in").value) || 0) * (dc - 1));
  const existing = parseDrawerHeightsFromHidden(dc);

  // Establish baseline heights (top-to-bottom).
  // Priority: existing N values; then existing N-1 values + computed remainder; else equal split.
  drawerFrontDirty = Array(dc).fill(false);
  drawerFrontBaseline = Array(dc).fill(0);

  if (existing.length >= dc) {
    for (let i = 0; i < dc; i++) drawerFrontBaseline[i] = existing[i];
  } else if (existing.length === dc - 1) {
    const sumTop = existing.reduce((a,b)=>a+b,0);
    const last = usableNet - sumTop;
    for (let i = 0; i < dc - 1; i++) drawerFrontBaseline[i] = existing[i];
    drawerFrontBaseline[dc-1] = (Number.isFinite(last) && last > 0) ? last : (usableNet / dc);
  } else {
    const each = usableNet / dc;
    for (let i = 0; i < dc; i++) drawerFrontBaseline[i] = each;
  }

  // Build editable inputs for each drawer front (1..dc). Inputs are compact and stacked vertically.
  for (let i = 1; i <= dc; i++){
    const pf = document.createElement("div");
    pf.className = "pf";

    const lab = document.createElement("label");
    lab.textContent = `Drawer ${i}`;
    pf.appendChild(lab);

    const inp = document.createElement("input");
    inp.type = "number";
    inp.step = "0.001";
    inp.id = `drawer_front_h_${i}`;
    inp.placeholder = "in";
    inp.value = (Number.isFinite(drawerFrontBaseline[i-1]) ? drawerFrontBaseline[i-1].toFixed(3).replace(/\.?0+$/,"") : "");

    inp.addEventListener("input", () => {
      drawerFrontDirty[i-1] = true;
      recalcDrawerFrontHeights();
    });
    inp.addEventListener("change", () => {
      drawerFrontDirty[i-1] = true;
      recalcDrawerFrontHeights();
    });

    pf.appendChild(inp);
    wrap.appendChild(pf);
  }

  // Initial compute/sync
  recalcDrawerFrontHeights();
}

function recalcDrawerFrontHeights(){
  const t = $("cabinet_type").value;
  const dc = parseInt($("drawer_count").value || "0", 10) || 0;
  if (t !== "Base" || dc < 2) return;

  const usableNet = computeDrawerUsableInches() - ((parseFloat($("drawer_gap_in").value) || 0) * (dc - 1));
  if (!(Number.isFinite(usableNet) && usableNet > 0)) return;

  // Collect current values; fall back to baseline for non-dirty/invalid.
  const vals = Array(dc).fill(0);
  for (let i = 1; i <= dc; i++){
    const el = document.getElementById(`drawer_front_h_${i}`);
    if (!el) continue;
    const v = parseFloat(el.value);
    if (drawerFrontDirty[i-1] && Number.isFinite(v) && v > 0) {
      vals[i-1] = v;
    } else {
      vals[i-1] = drawerFrontBaseline[i-1] || 0;
    }
  }

  const dirtySum = vals.reduce((acc,v,idx)=>acc + (drawerFrontDirty[idx] ? v : 0), 0);
  const autoIdx = [];
  for (let i = 0; i < dc; i++){
    if (!drawerFrontDirty[i]) autoIdx.push(i);
  }

  const remaining = usableNet - dirtySum;
  if (autoIdx.length > 0){
    const each = remaining / autoIdx.length;
    autoIdx.forEach(idx => { vals[idx] = each; });
  }

  // Update UI values for auto fields (and keep baseline in sync)
  for (let i = 1; i <= dc; i++){
    const el = document.getElementById(`drawer_front_h_${i}`);
    if (!el) continue;
    if (!drawerFrontDirty[i-1]){
      el.value = (Number.isFinite(vals[i-1]) ? vals[i-1].toFixed(3).replace(/\.?0+$/,"") : "");
    }
  }
  drawerFrontBaseline = vals.slice();

  // Write full CSV back for Ruby to consume.
  const hidden = $("drawer_front_heights_in");
  if (hidden){
    hidden.value = vals.map(v => (Number.isFinite(v) ? v.toFixed(3).replace(/\.?0+$/,"") : "")).join(", ");
  }

  drawPreview();
  applyValidationToUI();
}

function updateDrawerHeightInputs(){
  const t = $("cabinet_type").value;
  const isBase = (t === "Base");
  const dc = parseInt($("drawer_count").value || "0", 10) || 0;

  // Only meaningful for Base:
  $("drawer_front_height_in").disabled = (!isBase || dc !== 1);
  $("drawer_gap_in").disabled = !isBase;

  // Rebuild the per-panel inputs whenever dc/type changes.
  rebuildDrawerFrontPanels();
}



function updateShelfRules(){
              const dc = parseInt($("drawer_count").value || "0", 10);
              const doorsOn = $("show_doors").checked;
              const drawersOnly = (dc >= 2) || (dc > 0 && !doorsOn);

              if (drawersOnly){
                $("shelf_count").value = "0";
                $("shelf_count").disabled = true;
              } else {
                $("shelf_count").disabled = false;
              }
              updateDrawerHeightInputs();
            }

function updateCubbiesAuto(){
  const type = $("cabinet_type").value;
  if (type !== "Cubbies") return;

  const w = parseFloat($("width_in").value || "0") || 0;
  const h = parseFloat($("height_in").value || "0") || 0;
  const thk = parseFloat($("panel_thk_in").value || "0.75") || 0.75;
  const toeH = parseFloat($("toe_height_in").value || "0") || 0;
  const target = parseFloat($("cubby_target_in") ? $("cubby_target_in").value : "12") || 12;

  // Validation bounds (UI-level)
  // Width: 12-48, Height: 24-90
  // Use a carcass clear height similar to Ruby:
  // clear_h = (h - toeH) - thk  (top clearance from bottom deck top to cabinet top)
  const innerW = Math.max(0, w - 2 * thk);
  const clearH = Math.max(0, (h - toeH) - thk);

  function chooseDivisions(clearLen, thickness, tgt){
    let best = null;
    for (let div = 1; div <= 20; div++){
      const opening = (clearLen - ((div - 1) * thickness)) / div;
      if (!(opening >= 10 && opening <= 16)) continue;
      const score = Math.abs(opening - tgt);
      if (!best || score < best.score) best = {div, opening, score};
    }
    if (best) return best.div;

    // Fallback: choose the largest div with opening >= 10 (even if >16), else 1
    let fallback = 1;
    for (let div = 2; div <= 20; div++){
      const opening = (clearLen - ((div - 1) * thickness)) / div;
      if (opening >= 10) fallback = div;
    }
    return fallback;
  }

  const cols = chooseDivisions(innerW, thk, target);
  const rows = chooseDivisions(clearH, thk, target);

  const shelves = Math.max(0, rows - 1);
  const parts = Math.max(0, cols - 1);

  if ($("shelf_count")) $("shelf_count").value = shelves.toString();
  if ($("partition_count")) $("partition_count").value = parts.toString();

  requestModelNumber();
  drawPreview();
}


            function autoName(){
              if (!$("auto_name").checked) return;

              const t = $("cabinet_type").value;
              const code = ($("catalog_code") ? $("catalog_code").value : "").trim();
              const w = fmtNum($("width_in").value);
              const d = fmtNum($("depth_in").value);
              const h = fmtNum($("height_in").value);
              const doors = Math.max(0, parseInt($("door_count")?.value || "0", 10) || 0);
              const drawers = Math.max(0, parseInt($("drawer_count")?.value || "0", 10) || 0);
              const shelves = Math.max(0, parseInt($("shelf_count")?.value || "0", 10) || 0);

              const cabinetLabel = {
                "Base": drawers >= 2 ? "Drawer Base Cabinet" : "Base Cabinet",
                "Wall": "Wall Cabinet",
                "Tall": "Tall Cabinet",
                "Sink Base": "Sink Base Cabinet",
                "ADA Sink": "ADA Wall Sink Cabinet",
                "Trash Can": "Trash Pull-Out Cabinet",
                "Cubbies": "Cubby Cabinet",
                "Appliance End Panel": "Appliance End Panel",
                "Diagonal Corner Base": "Diagonal Corner Base Cabinet",
                "Pie-Cut Corner Base": "Pie-Cut Corner Base Cabinet",
                "Blind Corner Base": "Blind Corner Base Cabinet"
              }[t] || `${t} Cabinet`;

              const features = [];
              if (doors > 0) features.push(`${doors} ${doors === 1 ? "Door" : "Doors"}`);
              if (drawers > 0) features.push(`${drawers} ${drawers === 1 ? "Drawer" : "Drawers"}`);
              if (shelves > 0) features.push(`${shelves} Adjustable ${shelves === 1 ? "Shelf" : "Shelves"}`);

              const parts = [];
              if (code) parts.push(code);
              parts.push(cabinetLabel);
              parts.push(`${w}"W × ${h}"H × ${d}"D`);
              if (features.length) parts.push(features.join(", "));
              $("name").value = parts.join(" — ");
            }

            function uiValidate(){
              const issues = [];
              const warnings = [];

              const type = $("cabinet_type").value;

              const W = parseFloat($("width_in").value);
              const H = parseFloat($("height_in").value);
              const D = parseFloat($("depth_in").value);
              const ct = parseFloat($("countertop_thk_in").value);

              const toeH = parseFloat($("toe_height_in").value);
              const toeR = parseFloat($("toe_recess_in").value);

              const overlayMode = $("overlay_mode").value;
              const revealEdge = (overlayMode === "True Full Overlay") ? 0 : (parseFloat($("reveal_edge_in").value) || 0);
              const revealCenter = parseFloat($("reveal_center_in").value) || 0;

              const dc = parseInt($("drawer_count").value, 10) || 0;
              const showDoors = $("show_doors").checked;

              const drawerFrontH = parseFloat($("drawer_front_height_in").value) || 0;
              const drawerGap = parseFloat($("drawer_gap_in").value) || 0;
const drawerHeightsRaw = ($("drawer_front_heights_in") ? ($("drawer_front_heights_in").value || "") : "");

// Multi-drawer sizing validation (Base only).
// If Drawer Front Heights is blank, drawers will be equal-height.
// If provided, bottom drawer is ALWAYS auto-calculated to fill the remainder.
// You may enter N-1 values (recommended). If you enter N values, the last value is ignored.
if (type === "Base" && dc >= 2) {
  const cabinetTop = H - ((type === "Sink Base" || type === "ADA Sink") ? (parseFloat($("countertop_thk_in").value) || 0) : 0);
  const usable = (cabinetTop - toeH - 2*revealEdge) - (drawerGap * (dc - 1));
  const raw = (drawerHeightsRaw || "").trim();

  if (raw) {
    const toks = raw.split(/[;,\s]+/).map(s => (s || "").trim()).filter(Boolean);
    const valsAll = toks.map(t => parseFloat(t));

    if (valsAll.some(v => !Number.isFinite(v) || v <= 0)) {
      issues.push("Drawer Front Heights values must be positive numbers (inches).");
    } else if (valsAll.length < (dc - 1)) {
      issues.push(`Drawer Front Heights must provide at least ${dc-1} values (top drawers). The bottom drawer is auto-calculated.`);
    } else {
      const vals = valsAll.slice(0, dc - 1); // ignore any extra; bottom is computed
      const sumTop = vals.reduce((a,b) => a + b, 0);
      const bottom = usable - sumTop;

      const tol = 1/64;
      if (bottom <= tol) issues.push("Drawer Front Heights do not leave a positive height for the bottom drawer.");
      if (sumTop > (usable + tol)) issues.push("Drawer Front Heights exceed the available opening height.");
    }
  }
}


              const isSink = (type === "Sink Base" || type === "ADA Sink");
              const isADA = (type === "ADA Sink");
              const isCubbies = (type === "Cubbies");

              if (Number.isNaN(W) || W <= 0) issues.push("Width must be > 0.");
              if (!Number.isNaN(W) && W > 48) issues.push("Width exceeds 48\\\" maximum.");
              if (Number.isNaN(D) || D <= 0) issues.push("Depth must be > 0.");
              if (Number.isNaN(H) || H <= 0) issues.push("Height must be > 0.");

              if (isSink && !isADA) {
                if (Number.isNaN(ct) || ct <= 0) issues.push("Countertop thickness must be > 0.");
                if (!Number.isNaN(H) && !Number.isNaN(ct) && H <= ct) issues.push("Finished height must exceed countertop thickness.");
              }

              if (isADA) {
                const frontRail = num("front_rail_height_in", 5);
                if (W < 30 || W > 48) issues.push("Model 10580 width must be between 30\" and 48\".");
                if (Math.abs(H - 32) > 0.001) issues.push("Model 10580 height is fixed at 32\".");
                if (![24, 29].some(value => Math.abs(D - value) < 0.001)) issues.push("Model 10580 depth must be 24\" or 29\".");
                if (![0.5, 0.625, 0.75].some(value => Math.abs(num("panel_thk_in", 0) - value) < 0.001)) issues.push("Material thickness must be 1/2\", 5/8\", or 3/4\".");
                if (frontRail < 4 || frontRail > 6) issues.push("Front rail height must be between 4\" and 6\".");
                if ((W - 2 * num("panel_thk_in", 0.75)) < 30) issues.push("Clear knee width must be at least 30\".");
                if ((H - frontRail) < 27) issues.push("Clear knee height must be at least 27\".");
                if (W > 42 && !$("second_mount_rail")?.checked) warnings.push("Widths over 42\" should use a second rear rail or concealed steel reinforcement.");
              }

              if (!isADA) {
                if (Number.isNaN(toeH) || toeH < 0) issues.push("Toe height must be >= 0.");
                if (!Number.isNaN(H) && !Number.isNaN(toeH) && toeH >= H) issues.push("Toe height must be less than finished height.");
                if (!Number.isNaN(D) && !Number.isNaN(toeR) && toeR >= D) issues.push("Toe recess must be less than cabinet depth.");
              }

              if (type !== "Base" && dc > 0) warnings.push("Drawers are only generated for Base cabinets.");
              if (type === "Base" && dc >= 2 && showDoors) warnings.push("Doors will be disabled automatically when drawer count is 2 or more.");

              if (revealEdge < 0) issues.push("Reveal Edge must be >= 0.");
              if (revealCenter < 0) issues.push("Reveal Center must be >= 0.");

              // Door-fit warnings (do not block)
              if (showDoors && type === "Base" && dc === 1 && !Number.isNaN(H) && !Number.isNaN(toeH)) {
                const finishedTop = H;
                const cabinetTop = finishedTop; // no countertop for Base
                const carcassTop = cabinetTop - 0; // same
                const carcassH = carcassTop - toeH;

                const remainingDoorSpan = carcassH - drawerFrontH - drawerGap;
                const doorH = remainingDoorSpan - (2 * revealEdge);
                if (remainingDoorSpan <= 0 || doorH <= 0) {
                  warnings.push("Doors will be skipped automatically (insufficient height below top drawer). Reduce drawer front height/gap or Reveal Edge, or increase cabinet height.");
                }
              }

              if (isADA) {
                const kneeH = parseFloat($("ada_knee_clear_h_in").value) || 27;
                if (kneeH < 27) warnings.push("ADA: knee clearance height is typically 27\\\" minimum.");
                const kneeD = parseFloat($("ada_knee_depth_in").value) || 20;
                if (kneeD < 17 || kneeD > 25) issues.push("ADA knee depth must be 17–25\\\".");
              }

              return { issues, warnings };
            }

            function applyValidationToUI(){
              const { issues, warnings } = uiValidate();

              const placeBtn = $("place_new");
              const editBtn = $("apply_edit");
              const warningsEl = $("warnings");
              const statusEl = $("place_status");

              if (issues.length) {
                if (placeBtn) placeBtn.disabled = true;
                if (editBtn) editBtn.disabled = true;
                warningsEl.innerHTML = `<div class="warn">${issues.map(s => s.replace(/</g,"&lt;")).join("<br>")}</div>`;
                statusEl.textContent = "Fix the errors to enable placement.";
              } else {
                if (placeBtn) placeBtn.disabled = false;
                if (editBtn) editBtn.disabled = false;
                const w = warnings.length
                  ? `<div class="warn" style="background:#fffdf2;border-color:#ffe3a1;color:#6a4b00;">${warnings.map(s => s.replace(/</g,"&lt;")).join("<br>")}</div>`
                  : "";
                warningsEl.innerHTML = w;
                statusEl.textContent = warnings.length ? "Ready to place (some items may auto-adjust)." : "Ready to place.";
              }
            }

            // -----------------------------------------------------------------
            // Placement debounce / re-entrancy guard
            // -----------------------------------------------------------------
            let _placing = false;
            function beginPlace(){
              if (_placing) return false;
              _placing = true;
              const statusEl = $("place_status");
              if (statusEl) statusEl.textContent = "Placing…";
              const b1 = $("place_new");
              const b2 = $("apply_edit");
              if (b1) b1.disabled = true;
              if (b2) b2.disabled = true;
              // Fail-safe: re-enable if Ruby never responds.
              window.setTimeout(() => { if (_placing) window.on_place_done(false); }, 4000);
              return true;
            }

            window.on_place_done = (ok) => {
              _placing = false;
              // Re-run validation (this restores enabled/disabled state appropriately).
              try { applyValidationToUI(); } catch (_) {}
              const statusEl = $("place_status");
              if (statusEl && ok === false) statusEl.textContent = statusEl.textContent || "Ready to place.";
            };

            function drawLineRect(ctx, x, y, w, h){
              ctx.strokeRect(x, y, w, h);
            }

function drawPartDims(ctx, x, y, wpx, hpx, wIn, hIn){
  // Draw a centered WxH label for a front/door. Skip if too small.
  if (!(wpx > 40 && hpx > 18)) return;
  const label = `${fmtNum(wIn)} × ${fmtNum(hIn)}`;
  ctx.save();
  ctx.font = "11px Arial";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // Measure + draw subtle background for legibility
  const tw = ctx.measureText(label).width;
  const bx = x + wpx/2 - (tw/2) - 4;
  const by = y + hpx/2 - 7;
  const bw = tw + 8;
  const bh = 14;

  ctx.fillStyle = "rgba(255,255,255,0.75)";
  ctx.fillRect(bx, by, bw, bh);

  ctx.fillStyle = "rgb(40,40,40)";
  ctx.fillText(label, x + wpx/2, y + hpx/2);
  ctx.restore();
}


            function drawPreview(){
              const canvas = $("preview");
              const ctx = canvas.getContext("2d");

              const type = $("cabinet_type").value;
              const W = parseFloat($("width_in").value);
              const H = parseFloat($("height_in").value);
              const D = parseFloat($("depth_in").value);

              ctx.clearRect(0, 0, canvas.width, canvas.height);

              if (Number.isNaN(W) || Number.isNaN(H) || W <= 0 || H <= 0) {
                ctx.font = "14px Arial";
                ctx.fillText("Enter valid Width and Height to preview.", 14, 30);
                applyValidationToUI();
                return;
              }

              const pad = 16;
              const viewW = canvas.width - pad * 2;
              const viewH = canvas.height - pad * 2;

              const scale = Math.min(viewW / W, viewH / H);
              const ox = pad + (viewW - W * scale) / 2;
              const oy = pad + (viewH - H * scale) / 2;

              // Appliance End Panel preview (side elevation: Depth x (Height to underside of countertop))
              if (type === "Appliance End Panel") {
                const ct = parseFloat(($("countertop_thk_in") && $("countertop_thk_in").value) || "0") || 0;
                const panelH = Math.max(0.0, H - ct);
                const panelW = (Number.isNaN(D) || D <= 0) ? W : D; // fall back to W if depth missing
                const scaleA = Math.min(viewW / panelW, viewH / Math.max(panelH, 0.001));
                const oxA = pad + (viewW - panelW * scaleA) / 2;
                const oyA = pad + (viewH - panelH * scaleA) / 2;

                // Panel outline
                ctx.save();
                ctx.lineWidth = 2;
                ctx.strokeStyle = "rgb(45,45,45)";
                ctx.strokeRect(oxA, oyA, panelW * scaleA, panelH * scaleA);

                // Front return indicator (1.5" strip at the front edge)
                const ret = 1.5;
                if (panelW > ret) {
                  ctx.setLineDash([6, 4]);
                  const xRet = oxA + (panelW - ret) * scaleA;
                  ctx.beginPath();
                  ctx.moveTo(xRet, oyA);
                  ctx.lineTo(xRet, oyA + panelH * scaleA);
                  ctx.stroke();
                  ctx.setLineDash([]);
                }

                // Label
                ctx.font = "12px Arial";
                ctx.fillStyle = "rgb(45,45,45)";
                ctx.fillText("AEP", oxA + 6, oyA + 16);
                ctx.restore();

                applyValidationToUI();
                return;
              }


              // outer
              ctx.lineWidth = 2;
              ctx.strokeStyle = "rgb(60,60,60)";
              drawLineRect(ctx, ox, oy, W*scale, H*scale);


              // Finished end labels
              const finLeft  = $("finish_left_end") && $("finish_left_end").checked;
              const finRight = $("finish_right_end") && $("finish_right_end").checked;
              if (finLeft || finRight) {
                ctx.save();
                ctx.font = "12px Arial";
                ctx.fillStyle = "rgb(40,40,40)";
                ctx.textBaseline = "middle";
                const midY = oy + (H * scale) / 2;
                if (finLeft) {
                  ctx.textAlign = "right";
                  ctx.fillText("FIN END", ox - 6, midY);
                }
                if (finRight) {
                  ctx.textAlign = "left";
                  ctx.fillText("FIN END", ox + W * scale + 6, midY);
                }
                ctx.restore();
              }

                            const isSink = (type === "Sink Base" || type === "ADA Sink");
              const isADA  = (type === "ADA Sink");

              // Finished top line (non-sink types)
              if (!isSink) {
                ctx.lineWidth = 1;
                ctx.setLineDash([4, 3]);
                ctx.strokeStyle = "rgb(120,120,120)";
                ctx.beginPath();
                ctx.moveTo(ox, oy);
                ctx.lineTo(ox + W*scale, oy);
                ctx.stroke();
                ctx.setLineDash([]);
              }

              const overlayMode = $("overlay_mode").value;
              const revealEdge = (overlayMode === "True Full Overlay") ? 0 : (parseFloat($("reveal_edge_in").value) || 0);
              const revealCenter = parseFloat($("reveal_center_in").value) || 0;

              const showDoors = $("show_doors").checked;
              const dc = parseInt($("drawer_count").value, 10) || 0;

              const toeAllowed = typeAllowsToeKick(type);

              const ct = 0;
              const toeH = toeAllowed ? (parseFloat($("toe_height_in").value) || 0) : 0;

              // Cabinet top below countertop
              const cabinetTop = H - ct;

              // Toe zone (only for types that actually have a toe-kick)
              if (toeAllowed && toeH > 0) {
                const toePx = Math.min(toeH, H) * scale;
                ctx.fillStyle = "rgba(0,0,0,0.06)";
                ctx.fillRect(ox, oy + (H*scale - toePx), W*scale, toePx);

                // Toe recess indicator (front band)
                const toeR = parseFloat($("toe_recess_in").value) || 0;
                if (toeR > 0 && D > 0) {
                  ctx.fillStyle = "rgba(0,0,0,0.03)";
                  ctx.fillRect(ox, oy + (H*scale - toePx), W*scale, toePx * 0.40);
                }
              }

              // Countertop thickness band (sink types)
              if (false && isSink && ct > 0) {
                const yTop = oy;
                const yCabTop = oy + (H - cabinetTop) * scale;
                const slabHpx = (ct * scale);
                ctx.fillStyle = "rgba(0,0,0,0.05)";
                ctx.fillRect(ox, yTop, W*scale, slabHpx);

                // cabinet top line
                ctx.strokeStyle = "rgb(100,100,100)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(ox, yCabTop);
                ctx.lineTo(ox + W*scale, yCabTop);
                ctx.stroke();
              }

              // Face layout region (front view) only.
              // Compute face bounds (reveals)
              const fx = ox + (revealEdge * scale);
              const fw = (W - 2*revealEdge) * scale;

              // Cubbies preview: show open grid with toe kick.
              if (type === "Cubbies") {
                const thk = parseFloat($("panel_thk_in").value || "0.75") || 0.75;
                const toeH = parseFloat($("toe_height_in").value || "0") || 0;

                // Draw toe kick band (front view).
                if (toeH > 0) {
                  const yToeTop = oy + (H - toeH) * scale;
                  ctx.fillStyle = "rgba(0,0,0,0.04)";
                  ctx.fillRect(ox, yToeTop, W * scale, toeH * scale);
                  ctx.strokeStyle = "rgb(120,120,120)";
                  ctx.lineWidth = 1;
                  ctx.beginPath();
                  ctx.moveTo(ox, yToeTop);
                  ctx.lineTo(ox + W * scale, yToeTop);
                  ctx.stroke();
                }

                // Internal clear area (from inside top to inside bottom deck top).
                const innerLeft = ox + thk * scale;
                const innerRight = ox + (W - thk) * scale;
                const innerTop = oy + thk * scale;
                const innerBottom = oy + (H - toeH - thk) * scale;

                const innerW = Math.max(0, (W - 2 * thk));
                const clearH = Math.max(0, ((H - toeH) - thk));

                // Derive grid counts from UI (set by updateCubbiesAuto).
                const parts = parseInt(($("partition_count") ? $("partition_count").value : "0") || "0", 10) || 0;
                const shelves = parseInt(($("shelf_count") ? $("shelf_count").value : "0") || "0", 10) || 0;
                const cols = Math.max(1, parts + 1);
                const rows = Math.max(1, shelves + 1);

                // Compute opening sizes (matches Ruby: openings share the remaining clear space after dividers).
                const openingW = (innerW - ((cols - 1) * thk)) / cols;
                const openingH = (clearH - ((rows - 1) * thk)) / rows;

                // Guard against invalid numbers.
                if (openingW > 0 && openingH > 0 && innerBottom > innerTop) {
                  ctx.strokeStyle = "rgb(90,90,90)";
                  ctx.lineWidth = 1;

                  // Vertical partitions
                  for (let c = 1; c < cols; c++) {
                    const x = innerLeft + (c * openingW + (c - 1) * thk) * scale;
                    ctx.beginPath();
                    ctx.moveTo(x, innerTop);
                    ctx.lineTo(x, innerBottom);
                    ctx.stroke();
                  }

                  // Horizontal shelves
                  for (let r = 1; r < rows; r++) {
                    const y = innerTop + (r * openingH + (r - 1) * thk) * scale;
                    ctx.beginPath();
                    ctx.moveTo(innerLeft, y);
                    ctx.lineTo(innerRight, y);
                    ctx.stroke();
                  }

                  // Inner bounds line
                  ctx.strokeStyle = "rgb(140,140,140)";
                  ctx.beginPath();
                  ctx.rect(innerLeft, innerTop, (innerRight - innerLeft), (innerBottom - innerTop));
                  ctx.stroke();
                }

                applyValidationToUI();
                return;
              }

              // Sink false front
              if (isSink) {
                const ffH = parseFloat($("false_front_height_in").value) || 6;
                const ffTop = oy + (H - cabinetTop) * scale; // cabinet top y
                const ffY = ffTop + (revealEdge*scale);
                const ffHpx = ffH * scale;
                ctx.lineWidth = 2;
                ctx.strokeStyle = "rgb(40,40,40)";
                drawLineRect(ctx, fx, ffY, fw, ffHpx);
                 // Dimensions for false drawer front
                 drawPartDims(ctx, fx, ffY, fw, ffHpx, (W - 2*revealEdge), ffH);

                 // Doors below false front (Sink Base)
                 if (showDoors) {
                   const doorTop = (cabinetTop - ffH) - revealEdge;
                   const doorBottom = toeH + revealEdge;
                   const dh = doorTop - doorBottom;
                   if (dh > 0) {
                     const y = oy + (H - doorTop) * scale;
                     const hpx = dh * scale;
                     ctx.strokeStyle = "rgb(40,40,40)";
                     ctx.lineWidth = 2;

                     const splitDoor = doorSplitCountForWidth(W);
                     if (splitDoor === 2) {
                       const totalAvail = (W - 2*revealEdge - revealCenter);
                       const eachW = totalAvail / 2.0;
                       const leftX = fx;
                       const rightX = fx + (eachW + revealCenter) * scale;
                       const wpx = eachW * scale;

                       drawLineRect(ctx, leftX, y, wpx, hpx);
                       drawLineRect(ctx, rightX, y, wpx, hpx);

                       drawPartDims(ctx, leftX, y, wpx, hpx, eachW, dh);
                       drawPartDims(ctx, rightX, y, wpx, hpx, eachW, dh);
                     } else {
                       const wIn = (W - 2*revealEdge);
                       const wpx = wIn * scale;
                       drawLineRect(ctx, fx, y, wpx, hpx);
                       drawPartDims(ctx, fx, y, wpx, hpx, wIn, dh);
                     }
                   }
                 }


                // ADA apron + knee space
                if (isADA) {
                  const kneeH = parseFloat($("ada_knee_clear_h_in").value) || 27;
                  const apronH = parseFloat($("ada_apron_h_in").value) || 3;
                  const apronBottom = Math.max(kneeH, 0);
                  const apronTop = (cabinetTop - revealEdge) - ffH - 0.125;
                  const apronY = oy + (H - apronTop) * scale;
                  const apronHpx = apronH * scale;
                  ctx.strokeStyle = "rgb(90,90,90)";
                  ctx.setLineDash([6, 3]);
                  drawLineRect(ctx, fx, apronY, fw, apronHpx);
                  ctx.setLineDash([]);

                  // Knee clearance zone
                  const kneeY = oy + (H - kneeH) * scale;
                  ctx.fillStyle = "rgba(0,0,0,0.04)";
                  ctx.fillRect(ox, kneeY, W*scale, (H*scale - kneeY - 1));

                  ctx.fillStyle = "rgb(60,60,60)";
                  ctx.font = "11px Arial";
                  ctx.fillText("Knee clearance", ox + 8, kneeY + 14);
                }
              }

              // Drawers (Base)
              if (type === "Base" && dc > 0) {
                const drawerGap = parseFloat($("drawer_gap_in").value) || 0;
                const split = drawerSplitCountForWidth(W);
                const topDrawerH = parseFloat($("drawer_front_height_in").value) || 6;

                let stackHeights = [];
                if (dc === 1) {
                  stackHeights = [topDrawerH];
} else {
  const usable = (cabinetTop - toeH - 2*revealEdge) - (drawerGap * (dc - 1));
  const rawHeights = ($("drawer_front_heights_in") ? ($("drawer_front_heights_in").value || "") : "").trim();

  const tryHeights = (() => {
    if (!rawHeights) return null;
    const toks = rawHeights.split(/[;,\s]+/).map(s => (s || "").trim()).filter(Boolean);
    const vals = toks.map(t => parseFloat(t)).filter(v => Number.isFinite(v));
    if (!vals.length) return null;

    const tol = 1/64;
    let heights = vals.slice();
    const sum = heights.reduce((a,b) => a + b, 0);

    if (heights.length === (dc - 1)) {
      heights.push(usable - sum);
    } else if (heights.length === dc) {
      if (sum > (usable + tol)) return null;
      if (sum < (usable - tol)) heights[heights.length - 1] += (usable - sum);
    } else {
      return null;
    }

    if (heights.some(h => !(h > 0))) return null;
    return heights;
  })();

  if (tryHeights) {
    stackHeights = tryHeights;
  } else {
    const each = usable / dc;
    for (let i=0; i<dc; i++) stackHeights.push(each);
  }
}

                // y positions in pixels: draw from top of cabinet (below countertop) downward
                let zTop = cabinetTop - revealEdge;
                for (let i=0; i<stackHeights.length; i++) {
                  const hIn = stackHeights[i];
                  const zBot = zTop - hIn;

                  const y = oy + (H - zTop) * scale;
                  const hpx = hIn * scale;

                  ctx.strokeStyle = "rgb(40,40,40)";
                  ctx.lineWidth = 2;

                  if (split === 2) {
                    const centerGap = revealCenter * scale;
                    const halfW = (fw - centerGap) / 2;
                    drawLineRect(ctx, fx, y, halfW, hpx);
                    drawLineRect(ctx, fx + halfW + centerGap, y, halfW, hpx);
                    const wInHalf = (W - 2*revealEdge - revealCenter) / 2;
                    drawPartDims(ctx, fx, y, halfW, hpx, wInHalf, hIn);
                    drawPartDims(ctx, fx + halfW + centerGap, y, halfW, hpx, wInHalf, hIn);
                  } else {
                    drawLineRect(ctx, fx, y, fw, hpx);
                    const wInSingle = (W - 2*revealEdge);
                    drawPartDims(ctx, fx, y, fw, hpx, wInSingle, hIn);
                  }

                  zTop = zBot - drawerGap;
                }

                // Doors below if dc==1 and showDoors
                if (dc === 1 && showDoors) {
                  const doorTop = (cabinetTop - revealEdge) - topDrawerH - drawerGap;
                  const doorBottom = toeH + revealEdge;
                  const dh = doorTop - doorBottom;
                  if (dh > 0) {
                    const y = oy + (H - doorTop) * scale;
                    const hpx = dh * scale;
                    const splitDoor = doorSplitCountForWidth(W);

                    ctx.strokeStyle = "rgb(40,40,40)";
                    ctx.lineWidth = 2;

                    if (type === "Diagonal Corner Base") {
                      const diagWIn = 31.32;
                      const diagPx = Math.min(fw, diagWIn * scale);
                      const dx = fx + (fw - diagPx) / 2;
                      drawLineRect(ctx, dx, y, diagPx, hpx);
                      drawPartDims(ctx, dx, y, diagPx, hpx, diagWIn, dh);
                    } else if (type === "Pie-Cut Corner Base") {
                      const notchIn = Math.min(W, D) * (1 - (19.25 / 36));
                      const leafPx = Math.min(notchIn * scale, (fw - revealCenter * scale) / 2);
                      const totalPx = (2 * leafPx) + revealCenter * scale;
                      const px = fx + (fw - totalPx) / 2;
                      drawLineRect(ctx, px, y, leafPx, hpx);
                      drawLineRect(ctx, px + leafPx + revealCenter * scale, y, leafPx, hpx);
                      drawPartDims(ctx, px, y, leafPx, hpx, notchIn, dh);
                      drawPartDims(ctx, px + leafPx + revealCenter * scale, y, leafPx, hpx, notchIn, dh);
                    } else if (type === "Blind Corner Base") {
                      const openingPx = Math.min(18 * scale, fw);
                      drawLineRect(ctx, fx, y, openingPx, hpx);
                      drawLineRect(ctx, fx + openingPx + revealCenter * scale, y,
                        Math.max(fw - openingPx - revealCenter * scale, 0), hpx);
                      drawPartDims(ctx, fx, y, openingPx, hpx, 18, dh);
                    } else if (splitDoor === 2) {
                      const centerGap = revealCenter * scale;
                      const halfW = (fw - centerGap) / 2;
                      drawLineRect(ctx, fx, y, halfW, hpx);
                      drawLineRect(ctx, fx + halfW + centerGap, y, halfW, hpx);
                      const wInHalf = (W - 2*revealEdge - revealCenter) / 2;
                      drawPartDims(ctx, fx, y, halfW, hpx, wInHalf, dh);
                      drawPartDims(ctx, fx + halfW + centerGap, y, halfW, hpx, wInHalf, dh);
                    } else {
                      drawLineRect(ctx, fx, y, fw, hpx);
                      const wInSingle = (W - 2*revealEdge);
                      drawPartDims(ctx, fx, y, fw, hpx, wInSingle, dh);
                    }

                    // advance downward for next drawer front (gap between fronts)
                    zTop = zBot - drawerGap;
                  }
                }
              }

              // Standard doors (no drawers, non-sink)
              if (!isSink && showDoors && !(type === "Base" && dc >= 2)) {
                const splitDoor = doorSplitCountForWidth(W);

                // If Base + 1 drawer we handled above; skip here
                const skip = (type === "Base" && dc === 1);
                if (!skip) {
                  const doorTop = cabinetTop - revealEdge;
                  const doorBottom = toeH + revealEdge;
                  const dh = doorTop - doorBottom;

                  if (dh > 0) {
                    const y = oy + (H - doorTop) * scale;
                    const hpx = dh * scale;

                    ctx.strokeStyle = "rgb(40,40,40)";
                    ctx.lineWidth = 2;

                    if (type === "Diagonal Corner Base") {
                      const diagWIn = 31.32;
                      const diagPx = Math.min(fw, diagWIn * scale);
                      const dx = fx + (fw - diagPx) / 2;
                      drawLineRect(ctx, dx, y, diagPx, hpx);
                      drawPartDims(ctx, dx, y, diagPx, hpx, diagWIn, dh);
                    } else if (type === "Pie-Cut Corner Base") {
                      const notchIn = Math.min(W, D) * (1 - (19.25 / 36));
                      const leafPx = Math.min(notchIn * scale, (fw - revealCenter * scale) / 2);
                      const totalPx = (2 * leafPx) + revealCenter * scale;
                      const px = fx + (fw - totalPx) / 2;
                      drawLineRect(ctx, px, y, leafPx, hpx);
                      drawLineRect(ctx, px + leafPx + revealCenter * scale, y, leafPx, hpx);
                      drawPartDims(ctx, px, y, leafPx, hpx, notchIn, dh);
                      drawPartDims(ctx, px + leafPx + revealCenter * scale, y, leafPx, hpx, notchIn, dh);
                    } else if (type === "Blind Corner Base") {
                      const openingPx = Math.min(18 * scale, fw);
                      const fillerX = fx + openingPx + revealCenter * scale;
                      drawLineRect(ctx, fx, y, openingPx, hpx);
                      drawLineRect(ctx, fillerX, y, Math.max((fx + fw) - fillerX, 0), hpx);
                      drawPartDims(ctx, fx, y, openingPx, hpx, 18, dh);
                    } else if (splitDoor === 2) {
                      const centerGap = revealCenter * scale;
                      const halfW = (fw - centerGap) / 2;
                      drawLineRect(ctx, fx, y, halfW, hpx);
                      drawLineRect(ctx, fx + halfW + centerGap, y, halfW, hpx);
                      const wInHalf = (W - 2*revealEdge - revealCenter) / 2;
                      drawPartDims(ctx, fx, y, halfW, hpx, wInHalf, dh);
                      drawPartDims(ctx, fx + halfW + centerGap, y, halfW, hpx, wInHalf, dh);
                    } else {
                      drawLineRect(ctx, fx, y, fw, hpx);
                      const wInSingle = (W - 2*revealEdge);
                      drawPartDims(ctx, fx, y, fw, hpx, wInSingle, dh);
                    }

                    // advance downward for next drawer front (gap between fronts)
                    zTop = zBot - drawerGap;
                  }
                }
              }

              // Partitions indication (doors-only)
              const pc = parseInt($("partition_count").value, 10) || 0;
              const doorsOnly = showDoors && (type === "Base" ? (dc === 0) : true) && !isSink && !isADA;
              if (doorsOnly && pc > 0) {
                ctx.strokeStyle = "rgb(110,110,110)";
                ctx.lineWidth = 1;
                ctx.setLineDash([3,3]);

                const top = oy + (H - (cabinetTop - revealEdge)) * scale;
                const bottom = oy + (H - (toeH + revealEdge)) * scale;
                const ph = bottom - top;

                const openings = pc + 1;
                for (let i=1; i<=pc; i++) {
                  const t = i / openings;
                  const x = fx + (fw * t);
                  ctx.beginPath();
                  ctx.moveTo(x, top);
                  ctx.lineTo(x, top + ph);
                  ctx.stroke();
                }
                ctx.setLineDash([]);
              }

              // Label
              ctx.fillStyle = "rgb(40,40,40)";
              ctx.font = "12px Arial";
              const ctLabel = "";
              ctx.fillText(`${type}  W:${fmtNum(W)}  H:${fmtNum(H)}  D:${fmtNum(D)}${ctLabel}`, pad, canvas.height - 10);

              applyValidationToUI();
            }

            

window.set_model_number = (mn) => {
  const v = (mn || "").toString();
  const el = $("model_number"); if (el) el.value = v;
  const lm = $("last_model"); if (lm) lm.textContent = v;
};

function requestModelNumber(){
  try {
    const payload = gather();
    if (window.sketchup && sketchup.compute_model_number) {
      sketchup.compute_model_number(JSON.stringify(payload));
    }
  } catch(e) {}
}

function gather(){
              const t = $("cabinet_type").value;

              const defaultH =
                (t === "Wall") ? 30.0 :
                (t === "Tall") ? 84.0 : 34.5;

              const defaultD =
                (t === "Wall") ? 12.0 :
                (t === "ADA Sink") ? 21.0 : 24.0;

              return {
                catalog_code: $("catalog_code") ? $("catalog_code").value : "",
                cabinet_type: t,
                auto_name: $("auto_name").checked,
                room: ($("room") ? $("room").value : ""),
                name: $("name").value,

                width_in:  num("width_in", 30.0),
                depth_in:  num("depth_in", defaultD),
                height_in: num("height_in", defaultH),

                panel_thk_in: num("panel_thk_in", 0.75),
                back_thk_in:  num("back_thk_in", (t === "ADA Sink") ? 0.0 : 0.75),
                shelf_thk_in: num("shelf_thk_in", 0.75),
                drawer_front_thk_in: num("drawer_front_thk_in", 0.75),
                box_thk_in: num("box_thk_in", 0.75),
                construction_type: $("construction_type").value,
                cabinet_construction: $("cabinet_construction").value,
                door_style: $("door_style").value,
                drawer_box_style: $("drawer_box_style").value,
                hardware: $("hardware").value,
                mat_parts: $("mat_parts").value,
                finish_left_end: $("finish_left_end").checked,
                finish_right_end: $("finish_right_end").checked,

                top_mode: $("top_mode").value,
                stretcher_width_in: num("stretcher_width_in", 5.0),

                toe_height_in: num("toe_height_in", (t === "ADA Sink") ? 0.0 : 4.0),
                toe_recess_in: num("toe_recess_in", (t === "ADA Sink") ? 0.0 : 3.0),

                shelf_count: intNum("shelf_count", (t === "ADA Sink") ? 0 : 1),
                door_count: intNum("door_count", 0),

                drawer_count: intNum("drawer_count", 1),
                use_slides: $("use_slides").checked,
                drawer_front_height_in: num("drawer_front_height_in", 6.0),
                drawer_front_heights_in: ($("drawer_front_heights_in") ? $("drawer_front_heights_in").value : ""),
                drawer_gap_in: num("drawer_gap_in", 0.125),

                show_doors: $("show_doors").checked,
                door_thk_in: num("door_thk_in", 0.75),
                hinge_side: $("hinge_side").value,
                door_swing: $("door_swing").value,
                open_angle_deg: num("open_angle_deg", 95.0),

                overlay_mode: $("overlay_mode").value,
                reveal_edge_in: num("reveal_edge_in", 0.0625),
                reveal_center_in: num("reveal_center_in", 0.125),

                partition_count: intNum("partition_count", 0),
                add_wire_pulls: $("add_wire_pulls").checked,
                add_hinges: $("add_hinges").checked,
                add_door_bumpers: $("add_door_bumpers").checked,
                add_shelf_supports: $("add_shelf_supports").checked,
                add_cam_lock: $("add_cam_lock").checked,
                add_countertop_brackets: $("add_countertop_brackets").checked,
                automatic_double_door_threshold_in: num("automatic_double_door_threshold_in", 24),
                automatic_drawer_bank_split_threshold_in: num("automatic_drawer_bank_split_threshold_in", 37),
                trash_drawer_box_bottom_offset_in: num("trash_drawer_box_bottom_offset_in", 0.5),
                aep_front_return_width_in: num("aep_front_return_width_in", 1.5),
                aep_front_return_thk_in: num("aep_front_return_thk_in", 0.75),

                false_front_height_in: num("false_front_height_in", 6.0),
                countertop_thk_in: num("countertop_thk_in", 1.5),
                ada_knee_clear_h_in: num("ada_knee_clear_h_in", 27.0),
                ada_apron_h_in: num("ada_apron_h_in", 3.0),
                ada_knee_depth_in: num("ada_knee_depth_in", 20.0),
                ada_side_leg_depth_in: num("ada_side_leg_depth_in", 6.0),
                front_rail_height_in: num("front_rail_height_in", 5.0),
                mount_rail_height_in: num("mount_rail_height_in", 4.0),
                access_panel_type: $("access_panel_type")?.value || "Magnetic",
                fastener_type: $("fastener_type")?.value || "Confirmat",
                mounting_type: $("mounting_type")?.value || "Wall Rail",
                french_cleat: ($("mounting_type")?.value === "French Cleat"),
                second_mount_rail: !!$("second_mount_rail")?.checked,
                safety_tether: !!$("safety_tether")?.checked,
                // Materials/tags omitted (UI section removed)
                edit_target_pid: EDIT_TARGET_PID
              };
            }

            function wireEvents(){
              // Wire the primary action first. Optional catalog/preview controls
              // must never be able to prevent cabinet placement if one of them
              // fails while the dialog is initializing.
              const placeNew = $("place_new");
              if (placeNew) placeNew.addEventListener("click", () => {
                try {
                  const { issues } = uiValidate();
                  if (issues.length) { applyValidationToUI(); return; }
                  if (!beginPlace()) return;
                  const payload = gather();
                  payload.edit_target_pid = null; // always place new
                  if (window.sketchup && sketchup.place) {
                    sketchup.place(JSON.stringify(payload));
                  } else {
                    window.on_place_done(false);
                    const statusEl = $("place_status");
                    if (statusEl) statusEl.textContent = "SketchUp placement bridge is unavailable. Reopen the cabinet dialog.";
                  }
                } catch (error) {
                  window.on_place_done(false);
                  const statusEl = $("place_status");
                  if (statusEl) statusEl.textContent = `Unable to place cabinet: ${error.message || error}`;
                  console.error("Cabinet placement failed", error);
                }
              });

              $("catalog_search").addEventListener("input", () => renderCatalog($("catalog_code").value));
              $("catalog_category").addEventListener("change", () => renderCatalog());
              $("catalog_model").addEventListener("change", event => chooseCatalogModel(event.target.value, true));
              $("toggle_favorite").addEventListener("click", () => {
                const code = $("catalog_model").value; if (!code) return;
                let values = storedList("cabinet_favorites");
                values = values.includes(code) ? values.filter(value => value !== code) : values.concat(code);
                try { localStorage.setItem("cabinet_favorites", JSON.stringify(values)); } catch(_e) {} renderCatalog(code);
              });
              document.querySelectorAll(".catalog-tab").forEach(button => button.addEventListener("click", () => {
                CATALOG_MODE = button.dataset.mode;
                document.querySelectorAll(".catalog-tab").forEach(tab => tab.classList.toggle("active", tab === button));
                renderCatalog($("catalog_code").value);
              }));
              $("height_preset").addEventListener("change", () => {
                const v = $("height_preset").value;
                if (v) $("height_in").value = v;
                autoName(); updateDoorCount(); recalcDrawerFrontHeights(); drawPreview();
              });

              const _ct = $("cubby_target_in"); if (_ct) _ct.addEventListener("change", () => { updateCubbiesAuto(); });
              ["width_in","height_in","panel_thk_in","toe_height_in"].forEach(id => { const el = $(id); if (el) el.addEventListener("change", () => { updateCubbiesAuto(); }); });


              $("height_in").addEventListener("input", () => {
                setPresetFromHeight($("cabinet_type").value);
                autoName(); updateDoorCount(); recalcDrawerFrontHeights(); drawPreview();
              });

              $("name").addEventListener("input", () => { $("auto_name").checked = false; });

              $("overlay_mode").addEventListener("change", (e) => {
                setOverlayMode(e.target.value);
                drawPreview();
              });

              $("top_mode").addEventListener("change", () => {
                applyTopModeRulesForType($("cabinet_type").value);
                drawPreview();
              });

              $("cabinet_type").addEventListener("change", () => {
                const t = $("cabinet_type").value;
                if (window.applyImmediateTypeDefaults) window.applyImmediateTypeDefaults(t);
                applyTopModeRulesForType(t);
                populateHeightPresets(t);
                setPresetFromHeight(t);
                applyTypeRules();
              updateShelfRules();
                autoName();
                drawPreview();

                if (window.sketchup && sketchup.load_type) sketchup.load_type(t);
                requestModelNumber();
              });

              const _rt = $("reset_type"); if (_rt) _rt.addEventListener("click", () => {
                const t = $("cabinet_type").value;
                if (window.sketchup && sketchup.reset_type) sketchup.reset_type(t);
              });

              const _ra = $("reset_all"); if (_ra) _ra.addEventListener("click", () => {
                if (window.sketchup && sketchup.reset_all) sketchup.reset_all();
              });

              const _es = $("edit_selected"); if (_es) _es.addEventListener("click", () => {
                if (window.sketchup && sketchup.edit_selected) sketchup.edit_selected();
              });

              const _ce = $("cancel_edit"); if (_ce) _ce.addEventListener("click", () => {
                clearEditMode();
              });

              const _ple = $("apply_edit"); if (_ple) _ple.addEventListener("click", () => {
                const { issues } = uiValidate();
                if (issues.length) { applyValidationToUI(); return; }
                const payload = gather();
                if (!payload.edit_target_pid) { alert("No cabinet is currently in edit mode. Click 'Edit Selected' first."); return; }
                if (!beginPlace()) return;
                if (window.sketchup && sketchup.place) sketchup.place(JSON.stringify(payload));
              });

              [
                "width_in","depth_in","toe_height_in","toe_recess_in","shelf_count",
                "drawer_count","use_slides","drawer_front_height_in","drawer_front_heights_in","drawer_gap_in",
                "show_doors","door_swing","hinge_side","open_angle_deg",
                "reveal_edge_in","reveal_center_in","partition_count",
                "false_front_height_in","countertop_thk_in","ada_knee_clear_h_in","ada_apron_h_in","ada_knee_depth_in","ada_side_leg_depth_in"
              ].forEach(id => {
                const el = $(id);
                if (!el) return;
                el.addEventListener("input", () => { enforceMaxWidth(); updateDoorCount(); autoName(); recalcDrawerFrontHeights(); drawPreview(); requestModelNumber(); });
                el.addEventListener("change", () => { enforceMaxWidth(); updateDoorCount(); autoName(); recalcDrawerFrontHeights(); drawPreview(); requestModelNumber(); });
              });
// Finished Ends should live-update the preview and model number.
["finish_left_end","finish_right_end"].forEach(id => {
  const el = $(id);
  if (!el) return;
  el.addEventListener("change", () => { updateDoorCount(); autoName(); drawPreview(); requestModelNumber(); });
});

              // Drawers-only rule: if cabinet is drawers-only, shelves are forced off.
              $("drawer_count").addEventListener("change", () => { updateShelfRules(); updateDoorCount(); autoName(); drawPreview(); });
              $("show_doors").addEventListener("change", () => { updateShelfRules(); updateDoorCount(); autoName(); drawPreview(); });

            }

            window.set_form = (json) => {
              const supplied = (typeof json === "string") ? JSON.parse(json) : (json || {});
              // Keep the form complete when loading preferences written by an
              // older version. Missing/null values must not blank built-in defaults.
              const d = { ...EMBED_DEFAULTS_JSON };
              Object.entries(supplied).forEach(([key, value]) => {
                if (value !== null && value !== undefined) d[key] = value;
              });

              // Any manual load/reset is assumed to exit edit mode unless Ruby explicitly re-enters it.
              clearEditMode();

              $("cabinet_type").value = d.cabinet_type || "Base";
              if ($("catalog_code")) $("catalog_code").value = d.catalog_code || "";
              $("auto_name").checked = (d.auto_name !== false);
              if ($("room")) $("room").value = d.room || "";
              $("name").value = d.name || "";

              $("width_in").value = d.width_in;
              $("depth_in").value = d.depth_in;
              $("height_in").value = d.height_in;

              $("panel_thk_in").value = d.panel_thk_in;
              $("back_thk_in").value = d.back_thk_in;
              $("shelf_thk_in").value = d.shelf_thk_in ?? d.panel_thk_in;
              $("drawer_front_thk_in").value = d.drawer_front_thk_in ?? 0.75;
              $("box_thk_in").value = d.box_thk_in ?? 0.75;
              $("construction_type").value = d.construction_type || "Frameless";
              $("cabinet_construction").value = d.cabinet_construction || "Frameless";
              $("door_style").value = d.door_style || "Slab";
              $("drawer_box_style").value = d.drawer_box_style || "Melamine";
              $("hardware").value = d.hardware || "";

              $("finish_left_end").checked = !!d.finish_left_end;
              $("finish_right_end").checked = !!d.finish_right_end;

              $("top_mode").value = d.top_mode;
              $("stretcher_width_in").value = d.stretcher_width_in;

              $("toe_height_in").value = d.toe_height_in;
              $("toe_recess_in").value = d.toe_recess_in;

              $("shelf_count").value = d.shelf_count;

              $("drawer_count").value = (d.drawer_count ?? 0).toString();
              $("use_slides").checked = !!d.use_slides;
              $("drawer_front_height_in").value = d.drawer_front_height_in;
              if ($("drawer_front_heights_in")) $("drawer_front_heights_in").value = (d.drawer_front_heights_in ?? "");
              $("drawer_gap_in").value = d.drawer_gap_in;

              $("show_doors").checked = !!d.show_doors;
              $("door_thk_in").value = d.door_thk_in;
              $("hinge_side").value = d.hinge_side;
              $("door_swing").value = d.door_swing;
              $("open_angle_deg").value = d.open_angle_deg;

              $("overlay_mode").value = d.overlay_mode;
              $("reveal_edge_in").value = d.reveal_edge_in;
              $("reveal_center_in").value = d.reveal_center_in;

              $("partition_count").value = (d.partition_count ?? 0);
              $("add_wire_pulls").checked = d.add_wire_pulls !== false;
              $("add_hinges").checked = d.add_hinges !== false;
              $("add_door_bumpers").checked = d.add_door_bumpers !== false;
              $("add_shelf_supports").checked = d.add_shelf_supports !== false;
              $("add_cam_lock").checked = d.add_cam_lock !== false;
              $("add_countertop_brackets").checked = d.add_countertop_brackets !== false;
              $("automatic_double_door_threshold_in").value = d.automatic_double_door_threshold_in ?? 24;
              $("automatic_drawer_bank_split_threshold_in").value = d.automatic_drawer_bank_split_threshold_in ?? 37;
              $("trash_drawer_box_bottom_offset_in").value = d.trash_drawer_box_bottom_offset_in ?? 0.5;
              $("aep_front_return_width_in").value = d.aep_front_return_width_in ?? 1.5;
              $("aep_front_return_thk_in").value = d.aep_front_return_thk_in ?? 0.75;

              $("false_front_height_in").value = d.false_front_height_in;
              $("countertop_thk_in").value = d.countertop_thk_in;
              $("ada_knee_clear_h_in").value = d.ada_knee_clear_h_in;
              $("ada_apron_h_in").value = d.ada_apron_h_in;
              $("ada_knee_depth_in").value = d.ada_knee_depth_in;
              $("ada_side_leg_depth_in").value = d.ada_side_leg_depth_in;
              if ($("front_rail_height_in")) $("front_rail_height_in").value = d.front_rail_height_in ?? 5;
              if ($("mount_rail_height_in")) $("mount_rail_height_in").value = d.mount_rail_height_in ?? 4;
              if ($("access_panel_type")) $("access_panel_type").value = d.access_panel_type || "Magnetic";
              if ($("fastener_type")) $("fastener_type").value = d.fastener_type || "Confirmat";
              if ($("mounting_type")) $("mounting_type").value = d.mounting_type || (d.french_cleat ? "French Cleat" : "Wall Rail");
              if ($("second_mount_rail")) $("second_mount_rail").checked = !!d.second_mount_rail;
              if ($("safety_tether")) $("safety_tether").checked = !!d.safety_tether;

              const re = parseFloat($("reveal_edge_in").value);
              if (Number.isFinite(re) && re > 0) lastRevealEdge = re;
              // Materials / Tags section removed from UI in this build.
              // Keep compatibility with older saved prefs by only applying these fields if inputs exist.
              const optSet = (id, val) => { const el = $(id); if (el) el.value = (val ?? ""); };
              const optCheck = (id, val) => { const el = $(id); if (el) el.checked = !!val; };

              optSet("mat_parts", d.mat_parts);
              optSet("mat_hardware", d.mat_hardware);
              optSet("mat_countertop", d.mat_countertop);

              optSet("tag_carcass", d.tag_carcass);
              optSet("tag_doors", d.tag_doors);
              optSet("tag_drawers", d.tag_drawers);
              optSet("tag_drawerboxes", d.tag_drawerboxes);
              optSet("tag_shelves", d.tag_shelves);
              optSet("tag_toe", d.tag_toe);
              optSet("tag_back", d.tag_back);
              optSet("tag_hardware", d.tag_hardware);
              optSet("tag_countertop", d.tag_countertop);

              populateHeightPresets($("cabinet_type").value);
              setPresetFromHeight($("cabinet_type").value);
              setOverlayMode($("overlay_mode").value);
              enforceMaxWidth();
              updateDoorCount();
              applyTopModeRulesForType($("cabinet_type").value);
              applyTypeRules();
              autoName();
              drawPreview();
              requestModelNumber();
            };

            function bootstrapDialog(){
              // Populate from the packaged catalog immediately. The Ruby ready
              // callback refreshes this data later, but the picker no longer
              // depends on that asynchronous callback to become usable.
              try { initialize_catalog(EMBEDDED_CATALOG_FALLBACK, EMBED_DEFAULTS_JSON.catalog_code); } catch(error) { console.error("Catalog initialization failed", error); }
              // Populate first. A secondary control must never prevent core defaults.
              try { if (window.set_form) window.set_form(EMBED_DEFAULTS_JSON); } catch(error) { console.error("Default initialization failed", error); }
              try { wireEvents(); } catch(error) { console.error("Event initialization failed", error); }
              const notifyReady = () => {
                try {
                  if (window.sketchup && sketchup.ready) sketchup.ready();
                  else window.setTimeout(notifyReady, 50);
                } catch(error) { console.error("SketchUp ready callback failed", error); }
              };
              notifyReady();
            }

            if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", bootstrapDialog, { once: true });
            else bootstrapDialog();
