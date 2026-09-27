/* One person's page, one object. Everything on these ten layouts is drawn from here. */
PERSON.recorded = PERSON.questions.filter(function(x){ return x.v; }).length;
PERSON.main = PERSON.questions.filter(function(x){ return x.main; })[0];

function esc(t){ return String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

/* A YouTube still costs nothing to serve, so the page stays free to host.
   The iframe is only created when somebody actually presses play. */
function film(item, opts){
  opts = opts || {};
  if(!item || !item.v){
    return '<span class="film empty"><span class="none">' + (opts.none || "Not recorded yet") + '</span></span>';
  }
  /* YouTube's hqdefault is always 4:3, so a widescreen film comes back with
     black bands baked into it and an upright one with bars down the sides.
     hq720 is a true 16:9 frame with no bands, but it does not exist for every
     upload, so the 4:3 one stays behind it as a fallback. For an upright film
     the 4:3 frame is the right one: the 9:16 box crops it to the footage. */
  var up = item.portrait ? " up" : "";
  var four3 = "https://i.ytimg.com/vi/" + item.v + "/hqdefault.jpg";
  var src = item.portrait ? four3 : "https://i.ytimg.com/vi/" + item.v + "/hq720.jpg";
  return '<button class="film noshot' + up + '" data-yt="' + item.v + '" data-still="' + src +
         '"' + (src === four3 ? "" : ' data-yt2="' + four3 + '"') +
         (item.still ? ' data-fb="' + item.still + '"' : "") +
         ' aria-label="Play: ' + esc(item.q) + '">' +
         '<span class="plate"></span>' +
         '<span class="sh"></span><span class="play"></span>' +
         (item.len ? '<span class="dur">' + item.len + '</span>' : "") +
         (opts.tag ? '<span class="tag">' + opts.tag + '</span>' : "") +
         '</button>';
}

var WIRED = false;
function wire(){
  if(!WIRED){ WIRED = true;
  document.addEventListener("click", function(ev){
    var b = ev.target.closest ? ev.target.closest(".film[data-yt]") : null;
    if(!b) return;
    var f = document.createElement("iframe");
    f.src = "https://www.youtube-nocookie.com/embed/" + b.getAttribute("data-yt") +
            "?autoplay=1&rel=0&modestbranding=1";
    f.setAttribute("allow","autoplay; encrypted-media; fullscreen");
    f.setAttribute("allowfullscreen","");
    b.innerHTML = "";
    b.appendChild(f);
    b.removeAttribute("data-yt");
  }); }
  /* The still is fetched out of sight and only put into the page once it has
     loaded. A frame that never arrives leaves the plate standing — no broken
     icon, no flash of one, and never the portrait doing duty as a film frame. */
  function dress(b){
    var srcs = [b.getAttribute("data-still")];
    var yt2 = b.getAttribute("data-yt2");
    if(yt2) srcs.push(yt2);
    var fb = b.getAttribute("data-fb");
    if(fb && fb !== PERSON.photo) srcs.push(fb);
    (function tryNext(){
      var url = srcs.shift();
      if(!url) return;
      var probe = new Image();
      probe.onload = function(){
        if(!b.isConnected || !b.classList.contains("noshot")) return;
        var img = document.createElement("img");
        img.src = url; img.alt = "";
        b.insertBefore(img, b.querySelector(".sh"));  /* over the plate, under the shade */
        b.classList.remove("noshot");
      };
      probe.onerror = tryNext;
      probe.src = url;
    })();
  }
  document.querySelectorAll(".film[data-still]").forEach(dress);
}

function factRows(list){
  return (list || PERSON.facts).map(function(f){
    return '<div class="fact"><span class="k">' + f.k + '</span>' +
      (f.v ? '<span class="v">' + f.v + '</span>'
           : '<span class="v add" role="button" tabindex="0">' + (f.ask || "Add") + '</span>') +
      '</div>';
  }).join("");
}

/* The birthplace map. Drawn as SVG from Natural Earth, so it needs no tiles and no
   map provider. Pages that want it load map.js alongside this file. */
function mapBlock(){
  if(typeof PERSON_MAP === "undefined") return "";
  var rows = PERSON_PLACES.map(function(p){
    return '<li class="pl"><span class="n">' + p.i + '</span><div><span class="k">' + p.kind +
           '</span><span class="v">' + p.name + '</span><span class="c">' + p.co + '</span></div></li>';
  }).join("");
  return '<div class="geo"><div class="frame">' + PERSON_MAP + '</div>' +
         '<div><ol class="pls">' + rows + '</ol>' +
         '<p class="m">Lucknow is 1,583 km north of Bangalore; Mussoorie another 489 km up into the hills.</p>' +
         '</div></div>';
}
function mapSection(title){
  if(typeof PERSON_MAP === "undefined") return "";
  return '<section id="places"><div class="sec-hd"><p class="mo">Where he’s from</p><h2>' +
         (title || "Bangalore, and two schools a long way north") + '</h2>' +
         '<p>Three places we know without having to ask him — pinned to the town, not the country.</p></div>' +
         mapBlock() + '</section>';
}
