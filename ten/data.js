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
    { q:"Say your full name, where you were born, and the date.",
      note:"The warm-up. Sixty seconds, and it gets the first one out of the way.",
      easy:true, v:"3Uz6uZC9hik", len:"8:14", main:true },
    { q:"Who were your mother and father — their names, and what they did.",
      easy:true, v:"BjQqDWj1LQw", len:"6:02" },
    { q:"Your brothers and sisters, oldest to youngest.", easy:true, v:null },
    { q:"The schools — Mussoorie and Lucknow. What were they like?", easy:true, v:null },
    { q:"The house you grew up in. Walk me through the front door.",
      v:"WNfvuJr9164", len:"5:38" },
    { q:"Your first job, and your first wage.", easy:true, v:null },
    { q:"How you met Mum.", v:null },
    { q:"The wedding day.", v:null },
    { q:"The day each of your children was born.", v:null },
    { q:"The work you did, and the thing you are proudest of making.",
      v:"nVu__vyps9Q", len:"12:41" },
    { q:"The hardest year of your life, and how you got through it.", v:null },
    { q:"What would you say to whoever watches this in fifty years?",
      v:"aJ_RVsf90xg", len:"4:29" }
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
         '<img src="https://i.ytimg.com/vi/' + item.v + '/hqdefault.jpg" alt="" loading="lazy">' +
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
  var SPOTS = ["44% 26%","52% 30%","48% 22%","40% 32%","56% 28%","46% 36%"];
  function check(img){
    if(img.naturalWidth) return;
    var w = img.parentNode; if(!w) return;
    var i = Array.prototype.indexOf.call(document.querySelectorAll(".film"), w);
    var f = document.createElement("img");
    f.className = "fb";
    f.src = LUIS.photo;
    f.alt = "";
    f.style.objectPosition = SPOTS[(i < 0 ? 0 : i) % SPOTS.length];
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
