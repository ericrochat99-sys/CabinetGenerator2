const DEFAULTS = {{DEFAULTS_JSON}};
let SETTINGS = {{SETTINGS_JSON}};

function $(id){ return document.getElementById(id); }

function setValue(k, v){
  const el = $(k);
  if(!el) return;
  if(el.type === "checkbox") el.checked = !!v;
  else el.value = v;
}

function render(){
  Object.keys(DEFAULTS).forEach(k => setValue(k, SETTINGS[k] ?? DEFAULTS[k]));
}


function syncPullKind(){
  const sel = $("pull_kind");
  const cb = $("add_wire_pulls");
  if(!sel || !cb) return;
  // Keep legacy checkbox in sync for backward compatibility.
  cb.checked = (sel.value === "wire_pull");
}

function set_form(d){
  // Apply values to elements by id; fall back to DEFAULTS
  if(!d) d = {};
  SETTINGS = Object.assign({}, DEFAULTS, d);
  Object.keys(DEFAULTS).forEach(k => setValue(k, SETTINGS[k] ?? DEFAULTS[k]));

  // Ensure pull style is present (older settings won't have it)
  if($("pull_kind") && !("pull_kind" in SETTINGS)){
    $("pull_kind").value = ($("add_wire_pulls") && $("add_wire_pulls").checked) ? "wire_pull" : "none";
  }
  syncPullKind();

  // Post-fill recompute pipeline (guarded)
  try{ if(window.populateHeightPresets) populateHeightPresets(); }catch(e){}
  try{ if(window.setPresetFromHeight) setPresetFromHeight(); }catch(e){}
  try{ if(window.setOverlayMode) setOverlayMode(); }catch(e){}
  try{ if(window.enforceMaxWidth) enforceMaxWidth(); }catch(e){}
  try{ if(window.updateDoorCount) updateDoorCount(); }catch(e){}
  try{ if(window.applyTopModeRulesForType) applyTopModeRulesForType(); }catch(e){}
  try{ if(window.applyTypeRules) applyTypeRules(); }catch(e){}
  try{ if(window.autoName) autoName(); }catch(e){}
  try{ if(window.drawPreview) drawPreview(); }catch(e){}
  try{ if(window.requestModelNumber) requestModelNumber(); }catch(e){}
}

// Pull style UI wiring
document.addEventListener("change", (ev) => {
  const t = ev.target;
  if(!t) return;
  if(t.id === "pull_kind"){
    syncPullKind();
    try{ if(window.drawPreview) drawPreview(); }catch(e){}
  }else if(t.id === "add_wire_pulls"){
    // If user toggles legacy checkbox (e.g., via older UI), reflect it in the selector
    const sel = $("pull_kind");
    if(sel) sel.value = t.checked ? "wire_pull" : "none";
    try{ if(window.drawPreview) drawPreview(); }catch(e){}
  }
});

function collect(){
  const out = {};
  Object.keys(DEFAULTS).forEach(k => {
    const el = $(k);
    if(!el) return;
    if(el.type === "checkbox") out[k] = !!el.checked;
    else out[k] = el.value;
  });
  return out;
}

function save(){
  const data = collect();
  if(window.sketchup && sketchup.save_global_settings){
    sketchup.save_global_settings(JSON.stringify(data));
  }
}

function resetDefaults(){
  if(!confirm("Reset global defaults?")) return;
  SETTINGS = Object.assign({}, DEFAULTS);
  render();
}

$("save").addEventListener("click", save);
$("reset").addEventListener("click", resetDefaults);
$("close").addEventListener("click", () => window.close());

render();
