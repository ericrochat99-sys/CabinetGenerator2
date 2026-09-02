function copyCsv(){
  const el = document.getElementById('csv');
  el.focus(); el.select();
  document.execCommand('copy');
}
