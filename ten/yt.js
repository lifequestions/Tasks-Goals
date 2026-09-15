/* Channel-shaped helpers over the same LUIS data. */
var HANDLE = "@luisdesouza";
function when(x){ return x.v ? "Recorded · September 2026" : "Not recorded yet"; }

function vcard(x, i){
  return '<div class="vcard' + (x.v ? "" : " todo") + '">' + film(x, {none:"Not recorded"}) +
         '<p class="t">' + ("0"+(i+1)).slice(-2) + '. ' + esc(x.q) + '</p>' +
         '<p class="m">' + (x.v ? x.len + " · " + when(x) : (x.easy ? "An easy one · two minutes" : "Not recorded yet")) + '</p></div>';
}
function upcard(x, i){
  return '<div class="ucard">' + film(x, {none:"—"}) +
         '<div><p class="t">' + ("0"+(i+1)).slice(-2) + '. ' + esc(x.q) + '</p>' +
         '<p class="m">Luis de Souza</p><p class="m">' + (x.v ? x.len : "Not recorded yet") + '</p></div></div>';
}
function pitem(x, i){
  return '<div class="pitem"><span class="idx">' + (i+1) + '</span>' + film(x, {none:"—"}) +
         '<div><p class="t">' + esc(x.q) + '</p><p class="m">' +
         (x.v ? "Luis de Souza · " + x.len : (x.easy ? "An easy one · not recorded" : "Not recorded")) +
         '</p></div></div>';
}
function recRows(){
  return LUIS.facts.map(function(f){
    return '<span class="k">' + f.k + '</span>' +
      (f.v ? '<span>' + f.v + '</span>' : '<span class="add" role="button" tabindex="0">' + f.ask + '</span>');
  }).join("");
}
function ymap(){
  if(typeof LUIS_MAP === "undefined") return "";
  return '<div class="ymap"><div class="frame">' + LUIS_MAP + '</div><div class="places">' +
    LUIS_PLACES.map(function(p){
      return '<div class="r"><span class="n">' + p.i + '</span><span><span class="k">' + p.kind +
             '</span>' + p.name + '</span></div>'; }).join("") + '</div></div>';
}
function aboutBlock(){
  return '<div class="about"><div><h2>The record</h2><div class="rec">' + recRows() + '</div></div>' +
         '<div><h2>Where he’s from</h2>' + ymap() + '</div></div>';
}
function tabs(on){
  return '<nav class="ytabs">' + ["Home","Questions","Playlists","About"].map(function(t){
    return '<a href="#" class="' + (t === on ? "on" : "") + '">' + t + '</a>'; }).join("") + '</nav>';
}
