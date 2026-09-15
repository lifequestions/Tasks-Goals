/* One person's page, one object. Everything on these ten layouts is drawn from here. */
var LUIS = {
  name: "Luis James de Souza",
  first: "Luis",
  family: "de Souza",
  born: "4 February 1943",
  age: 83,
  bornIn: "Bangalore, India",
  photo: "dad.jpg",
  /* The easy layer. Typed in once, no camera needed — this is what makes the page
     look like something before a single answer has been recorded. */
  facts: [
    { k:"Full name",      v:"Luis James de Souza" },
    { k:"Born",           v:"4 February 1943" },
    { k:"Born in",        v:"Bangalore, India" },
    { k:"Mother, father", v:null, ask:"Their names, and what they did" },
    { k:"Brothers, sisters", v:null, ask:"Oldest to youngest" },
    { k:"School",         v:"St George’s College, Mussoorie" },
    { k:"School",         v:"La Martinière College, Lucknow" },
    { k:"First job",      v:null, ask:"What it was, and what it paid" },
    { k:"Married",        v:null, ask:"Who, when, and where" },
    { k:"Children",       v:null, ask:"Names and years" },
    { k:"Work",           v:null, ask:"The trade, and the years in it" },
    { k:"Lives in",       v:null, ask:"And everywhere before it" }
  ],
  questions: [
    { q:"The house you grew up in — walk me through the front door. Which room did everybody end up in?",
      note:"The warm-up. Sixty seconds, and it gets the first one out of the way.",
      easy:true, v:"3Uz6uZC9hik", len:"8:14", still:"s-main.jpg", main:true },
    { q:"Who were your mother and father — their names, and what they did. Did you get on with them?",
      easy:true, v:"BjQqDWj1LQw", len:"6:02", still:"s-face.jpg" },
    { q:"Your brothers and sisters, oldest to youngest. Who were you closest to, and who did you fight with?", easy:true, v:null },
    { q:"What did your family eat, and who cooked it? What did you dread being given?", easy:true, v:null },
    { q:"The schools you went to. Were you happy there?",
      v:"WNfvuJr9164", len:"5:38", still:"s-room.jpg" },
    { q:"A teacher you still remember. What did they say to you that stuck?", easy:true, v:null },
    { q:"What did you do after school, before you were old enough to work? Where did you go when nobody knew where you were?", v:null },
    { q:"Your grandparents — what do you remember of them? What did their house smell like?", v:null },
    { q:"Sundays, when you were a boy. What was the routine, and who came?", v:null },
    { q:"The first time you remember being properly frightened. How old were you, and who came to get you?",
      v:"nVu__vyps9Q", len:"12:41", still:"s-hands.jpg" },
    { q:"What did your parents worry about? And what did they never talk about?", v:null },
    { q:"Start at the beginning — where were you born, and what did they name you? Tell me about the name, if there's a story in it.",
      v:"aJ_RVsf90xg", len:"4:29", still:"s-table.jpg" }
  ]
};
LUIS.recorded = LUIS.questions.filter(function(x){ return x.v; }).length;
LUIS.main = LUIS.questions.filter(function(x){ return x.main; })[0];

function esc(t){ return String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }

/* A YouTube still costs nothing to serve, so the page stays free to host.
   The iframe is only created when somebody actually presses play. */
function film(item, opts){
  opts = opts || {};
  if(!item || !item.v){
    return '<span class="film empty"><span class="none">' + (opts.none || "Not recorded yet") + '</span></span>';
  }
  return '<button class="film" data-yt="' + item.v + '" aria-label="Play: ' + esc(item.q) + '">' +
         '<img src="https://i.ytimg.com/vi/' + item.v + '/hqdefault.jpg" alt="" loading="lazy"' +
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
    f.src = img.getAttribute("data-fb") || LUIS.photo;
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
  return (list || LUIS.facts).map(function(f){
    return '<div class="fact"><span class="k">' + f.k + '</span>' +
      (f.v ? '<span class="v">' + f.v + '</span>'
           : '<span class="v add" role="button" tabindex="0">' + (f.ask || "Add") + '</span>') +
      '</div>';
  }).join("");
}

/* The birthplace map. Drawn as SVG from Natural Earth, so it needs no tiles and no
   map provider. Pages that want it load map.js alongside this file. */
function mapBlock(){
  if(typeof LUIS_MAP === "undefined") return "";
  var rows = LUIS_PLACES.map(function(p){
    return '<li class="pl"><span class="n">' + p.i + '</span><div><span class="k">' + p.kind +
           '</span><span class="v">' + p.name + '</span><span class="c">' + p.co + '</span></div></li>';
  }).join("");
  return '<div class="geo"><div class="frame">' + LUIS_MAP + '</div>' +
         '<div><ol class="pls">' + rows + '</ol>' +
         '<p class="m">Lucknow is 1,583 km north of Bangalore; Mussoorie another 489 km up into the hills.</p>' +
         '</div></div>';
}
function mapSection(title){
  if(typeof LUIS_MAP === "undefined") return "";
  return '<section id="places"><div class="sec-hd"><p class="mo">Where he’s from</p><h2>' +
         (title || "Bangalore, and two schools a long way north") + '</h2>' +
         '<p>Three places we know without having to ask him — pinned to the town, not the country.</p></div>' +
         mapBlock() + '</section>';
}
