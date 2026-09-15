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

/* Rows and cards that do carry a still, for the layouts that want one. */
function thumbRow(x, i){
  var n = ("0" + (i + 1)).slice(-2);
  var body = '<span class="idx">' + n + '</span>' + film(x, {none:"—"}) +
             '<span><span class="t">' + esc(x.q) + '</span><span class="m">' +
             (x.v ? "Recorded" : (x.easy ? "An easy one · two minutes" : "Not recorded yet")) + '</span></span>' +
             '<span class="dur">' + (x.v ? x.len : "—") + '</span>';
  return '<div class="trow ' + (x.v ? "on" : "off") + '">' + body + '</div>';
}
function thumbCard(x, i){
  return '<div class="tcard ' + (x.v ? "on" : "off") + '">' + film(x, {none:"Not recorded"}) +
         '<span class="t">' + ("0" + (i + 1)).slice(-2) + '. ' + esc(x.q) + '</span>' +
         '<span class="m">' + (x.v ? "Recorded · " + x.len : (x.easy ? "An easy one · two minutes" : "Not recorded yet")) + '</span></div>';
}
function sideBlock(){
  return '<div class="side">' +
    '<div class="pt"><img src="dad.jpg" alt="Luis James de Souza"></div>' +
    '<div class="namebl"><h1>Luis James de Souza</h1>' +
    '<p class="dates">Born 4 February 1943, Bangalore &nbsp;&middot;&nbsp; 83 years old</p>' +
    '<p class="blurb">Twelve questions, recorded at the kitchen table by his family, one at a time.</p></div>' +
    '<div><p class="sechd">The record</p><div class="rec">' + recRows() + '</div></div>' +
    '<div><p class="sechd">Where he&rsquo;s from</p>' + ymap() + '</div>' +
    '</div>';
}
