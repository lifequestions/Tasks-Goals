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
  /* Films shot on a phone held upright. YouTube's own still pillarboxes those into
     a 16:9 frame with black down both sides. An upright box cropped to 9:16 lands
     exactly on the footage inside those bars, so the still stays a real frame. */
  var up = item.portrait ? " up" : "";
  var src = "https://i.ytimg.com/vi/" + item.v + "/hqdefault.jpg";
  return '<button class="film' + up + '" data-yt="' + item.v + '" aria-label="Play: ' + esc(item.q) + '">' +
         '<img src="' + src + '" alt="" loading="lazy"' +
         (item.still ? ' data-fb="' + item.still + '"' : "") + '>' +
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
  /* Some previews block every external image. Say so rather than showing a broken icon. */
  /* Where the still cannot load (this preview blocks every outside image), stand a
     shaded frame of him in its place so the layout can still be judged. The real
     page pulls the frame straight from YouTube. */
  function check(img){
    if(img.naturalWidth) return;
    var w = img.parentNode; if(!w) return;
    var f = document.createElement("img");
    f.className = "fb";
    f.src = img.getAttribute("data-fb") || PERSON.photo;
    f.alt = "";
    w.insertBefore(f, w.firstChild);
    img.remove();
  }
  document.querySelectorAll(".film img").forEach(function(img){
    img.addEventListener("error", function(){ check(img); });
    setTimeout(function(){ check(img); }, 2500);
  });
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
