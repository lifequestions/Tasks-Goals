/* Channel-shaped helpers over the same PERSON data. */
function when(x){ return x.v ? "Recorded · September 2026" : "Not recorded yet"; }

function recRows(){
  return PERSON.facts.map(function(f){
    return '<span class="k">' + f.k + '</span>' +
      (f.v ? '<span class="v">' + f.v + '</span>'
           : '<span class="v"><span class="add" role="button" tabindex="0">' + f.ask + '</span></span>');
  }).join("");
}
function ymap(){
  if(typeof PERSON_MAP === "undefined") return "";
  return '<div class="ymap"><div class="frame">' + PERSON_MAP + '</div><div class="places">' +
    PERSON_PLACES.map(function(p){
      return '<div class="r"><span class="n">' + p.i + '</span><span><span class="k">' + p.kind +
             '</span><span class="v">' + p.name + '</span></span></div>'; }).join("") + '</div></div>';
}
function aboutBlock(){
  return '<div class="about"><div><p class="mo">The record</p><h2>What we know already</h2>' +
         '<div class="rec">' + recRows() + '</div></div>' +
         '<div><p class="mo">Where they\u2019re from</p><h2>Born, and schooled</h2>' + ymap() + '</div></div>';
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
  var meta = x.v ? "Recorded" + (x.recorded ? " &middot; " + x.recorded : "") +
                   (x.len ? " &middot; " + x.len : "")
                 : (x.easy ? "An easy one \u00b7 two minutes" : "Not recorded yet");
  /* A film that exists always carries a plain link out, so it is reachable
     even where the embed is refused. */
  if(x.v) meta += ' &middot; <a class="out" href="https://youtu.be/' + x.v +
                  '" target="_blank" rel="noopener">Watch on YouTube</a>';
  var title = '<span class="t">' + ("0" + (i + 1)).slice(-2) + '. ' + esc(x.q) + '</span>' +
              '<span class="m">' + meta + '</span>';
  /* Question first. It is what somebody is choosing between; the picture is
     just how you press it. */
  return '<div class="tcard ' + (x.v ? "on" : "off") + '">' + title +
         film(x, {none:"Not recorded"}) + '</div>';
}
function sideBlock(){
  return '<div class="side">' +
    '<div class="pt"><img src="dad.jpg" alt="' + PERSON.name + '"></div>' +
    '<div class="namebl"><h1>' + PERSON.name + '</h1>' +
    '<p class="dates">' + PERSON.born + ' &nbsp;&middot;&nbsp; ' + PERSON.age + '</p>' +
    '<p class="blurb">Twelve questions, recorded at the kitchen table by his family, one at a time.</p></div>' +
    '<div><p class="sechd">The record</p><div class="rec">' + recRows() + '</div></div>' +
    '<div><p class="sechd">Where he&rsquo;s from</p>' + ymap() + '</div>' +
    '</div>';
}

/* ---- sharing. Everything is a plain link except the copy button, so it works
   wherever the page is opened and needs no service of our own. ---- */
var ICON = {
  wa:'<svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 0 0-8.6 15l-1.3 4.7 4.8-1.3A10 10 0 1 0 12 2Zm0 18.2a8.2 8.2 0 0 1-4.2-1.2l-.3-.2-2.9.8.8-2.8-.2-.3A8.2 8.2 0 1 1 12 20.2Zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8s-.4-.1-.5.1-.6.8-.8 1-.3.2-.5.1a6.7 6.7 0 0 1-3.3-2.9c-.2-.4.2-.4.6-1.2a.4.4 0 0 0 0-.4l-.7-1.7c-.2-.4-.4-.4-.5-.4h-.5a1 1 0 0 0-.7.3 3 3 0 0 0-.9 2.2 5.2 5.2 0 0 0 1.1 2.7 11.8 11.8 0 0 0 4.5 4 5.3 5.3 0 0 0 3.3.7 2.7 2.7 0 0 0 1.8-1.3 2.2 2.2 0 0 0 .2-1.3c0-.1-.2-.2-.4-.3Z"/></svg>',
  fb:'<svg viewBox="0 0 24 24"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9a15 15 0 0 1 2.2.2v2.5h-1.2c-1.2 0-1.6.8-1.6 1.6V12h2.7l-.4 2.9h-2.3v7A10 10 0 0 0 22 12Z"/></svg>',
  mail:'<svg viewBox="0 0 24 24"><path d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Zm0 4.2-8 5-8-5V6l8 5 8-5Z"/></svg>',
  link:'<svg viewBox="0 0 24 24"><path d="M10.6 13.4a1 1 0 0 1 0-1.4l1.4-1.4a1 1 0 0 1 1.4 1.4l-1.4 1.4a1 1 0 0 1-1.4 0Zm-3 5.8a4 4 0 0 1 0-5.6l2.1-2.1 1.4 1.4-2.1 2.1a2 2 0 0 0 2.8 2.8l2.1-2.1 1.4 1.4-2.1 2.1a4 4 0 0 1-5.6 0Zm9-9-1.4-1.4 2.1-2.1a2 2 0 0 0-2.8-2.8l-2.1 2.1-1.4-1.4 2.1-2.1a4 4 0 0 1 5.6 5.6Z"/></svg>',
  share:'<svg viewBox="0 0 24 24"><path d="M18 16.1a3 3 0 0 0-2 .8l-7.1-4.2v-.7l7-4.1a3 3 0 1 0-1-2.2V6L8 10.1a3 3 0 1 0 0 3.8l7 4.2v.3a3 3 0 1 0 3-2.3Z"/></svg>'
};
var SHARE_N = 0;
function shareRow(cls){
  var sfx = SHARE_N++ ? "-" + SHARE_N : "";
  var u = encodeURIComponent(location.href);
  var t = encodeURIComponent(PERSON.name + " — twelve questions, in " +
          (PERSON.first ? "their" : "their") + " own voice");
  return '<div class="share ' + (cls || "") + '">' +
    '<span class="lab">Share this page</span>' +
    '<button id="shNative' + sfx + '" class="primary" hidden>' + ICON.share + '<span class="t">Share</span></button>' +
    '<button id="shCopy' + sfx + '">' + ICON.link + '<span class="t">Copy link</span></button>' +
    '<a href="https://wa.me/?text=' + t + '%20' + u + '" target="_blank" rel="noopener">' + ICON.wa + '<span class="t">WhatsApp</span></a>' +
    '<a href="https://www.facebook.com/sharer/sharer.php?u=' + u + '" target="_blank" rel="noopener">' + ICON.fb + '<span class="t">Facebook</span></a>' +
    '<a href="mailto:?subject=' + t + '&body=' + t + '%0A%0A' + u + '">' + ICON.mail + '<span class="t">Email</span></a>' +
    '</div>';
}
function wireShare(){
  document.querySelectorAll('[id^="shNative"]').forEach(wireNative);
  document.querySelectorAll('[id^="shCopy"]').forEach(wireCopy);
}
function wireNative(nat){
  if(nat && navigator.share){
    nat.hidden = false;
    nat.addEventListener("click", function(){
      navigator.share({title:PERSON.name, text:PERSON.name + " — in their own voice", url:location.href})
        .catch(function(){});
    });
  }
}
function wireCopy(c){
  c.addEventListener("click", function(){
    var done = function(){
      c.classList.add("done");
      c.innerHTML = ICON.link + '<span class="t">Link copied</span>';
      setTimeout(function(){ c.classList.remove("done"); c.innerHTML = ICON.link + '<span class="t">Copy link</span>'; }, 2200);
    };
    if(navigator.clipboard && navigator.clipboard.writeText){
      navigator.clipboard.writeText(location.href).then(done, done);
    } else {
      var i = document.createElement("input");
      i.value = location.href; document.body.appendChild(i); i.select();
      try{ document.execCommand("copy"); }catch(e){}
      i.remove(); done();
    }
  });
}
