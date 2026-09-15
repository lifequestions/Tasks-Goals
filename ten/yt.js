/* Channel-shaped helpers over the same LUIS data. */
function when(x){ return x.v ? "Recorded · September 2026" : "Not recorded yet"; }

function recRows(){
  return LUIS.facts.map(function(f){
    return '<span class="k">' + f.k + '</span>' +
      (f.v ? '<span class="v">' + f.v + '</span>'
           : '<span class="v"><span class="add" role="button" tabindex="0">' + f.ask + '</span></span>');
  }).join("");
}
function ymap(){
  if(typeof LUIS_MAP === "undefined") return "";
  return '<div class="ymap"><div class="frame">' + LUIS_MAP + '</div><div class="places">' +
    LUIS_PLACES.map(function(p){
      return '<div class="r"><span class="n">' + p.i + '</span><span><span class="k">' + p.kind +
             '</span><span class="v">' + p.name + '</span></span></div>'; }).join("") + '</div></div>';
}
function aboutBlock(){
  return '<div class="about"><div><p class="mo">The record</p><h2>What we know already</h2>' +
         '<div class="rec">' + recRows() + '</div></div>' +
         '<div><p class="mo">Where he\u2019s from</p><h2>Bangalore, and two schools north</h2>' + ymap() + '</div></div>';
}
function qcard(x, i, big){
  var n = ("0" + (i + 1)).slice(-2);
  var inner = '<span class="num">' + n + '</span>' +
              '<span class="qq">' + esc(x.q) + '</span>' +
              '<span class="st">' + (x.v ? '<span class="tri"></span>Play &middot; ' + x.len
                                         : (x.easy ? "Not recorded &middot; an easy one, two minutes"
                                                   : "Not recorded yet")) + '</span>';
  if(!x.v) return '<div class="qc off' + (big ? " big" : "") + '">' + inner + '</div>';
  return '<button class="film qc on' + (big ? " big" : "") + '" data-yt="' + x.v +
         '" aria-label="Play: ' + esc(x.q) + '">' + inner + '</button>';
}
function qrow(x, i, cls){
  cls = cls || "qrow";
  var n = ("0" + (i + 1)).slice(-2);
  var inner = '<span class="idx">' + n + '</span>' +
              '<span class="t">' + esc(x.q) + '</span>' +
              '<span class="dur">' + (x.v ? x.len : (x.easy ? "easy one" : "—")) + '</span>';
  if(!x.v) return '<div class="' + cls + ' off">' + inner + '</div>';
  return '<button class="film ' + cls + ' on" data-yt="' + x.v + '" aria-label="Play: ' + esc(x.q) + '">' +
         inner + '</button>';
}
