/* The photographs his father sent, and seven ways of putting them on his page.
   The prints are blank stand-ins: the real files have not arrived yet, so the
   pictures are empty paper at the right size and tone. The captions are his
   father's own words. */
var PHOTOS = [
  {src:"p-land-1.jpg", q:2, when:"c. 1950",
   cap:"That was the house I grew up in which we visited in 2001. It had been sold by then and the new " +
       "owner did some drastic modifications and it looked very different."},
  {src:"p-land-2.jpg", q:2, when:"A few years later",
   cap:"Another photo of the house taken a few years later. The Marli or Gardner is on the lawn. The " +
       "veranda can also be seen and I tell you about that in the video."},
  {src:"p-tall-1.jpg", q:null, when:"Undated", cap:"—"},
  {src:"p-tall-2.jpg", q:null, when:"Undated", cap:"—"},
  {src:"p-tall-3.jpg", q:null, when:"Undated", cap:"—"},
  {src:"p-tall-4.jpg", q:null, when:"Undated", cap:"—"}
];

function forQ(n){ return PHOTOS.filter(function(p){ return p.q === n; }); }

function plate(p, cls){
  return '<figure class="plate ' + (cls || "") + '">' +
         '<img class="print" src="' + p.src + '" alt="" loading="lazy">' +
         '<figcaption><b>' + p.when + '</b>' + p.cap + '</figcaption></figure>';
}

/* 1 — inside the card of the question they belong to */
function modeCard(){
  var ps = forQ(2); if(!ps.length) return;
  var card = document.getElementById("q2"); if(!card) return;
  card.insertAdjacentHTML("beforeend",
    '<div class="pstrip">' + ps.map(function(p){
      return '<img class="print" src="' + p.src + '" alt="" loading="lazy">'; }).join("") + '</div>' +
    '<p class="pcap"><b>In his words</b>' + ps[0].cap + '</p>');
}

/* 2 — one photograph the width of the page, above the questions */
function modePlate(){
  var p = PHOTOS[1], kq = document.querySelector(".kq");
  kq.insertAdjacentHTML("beforebegin",
    '<div class="pband">' + plate(p) + '</div>');
}

/* 3 — the same place, twice, dated */
function modePair(){
  var ps = forQ(2); if(ps.length < 2) return;
  var card = document.getElementById("q2"); if(!card) return;
  card.insertAdjacentHTML("beforeend",
    '<div class="ppair">' +
      '<figure><img class="print" src="' + ps[0].src + '" alt=""><figcaption><b>Then</b>The house he grew up in.</figcaption></figure>' +
      '<figure><img class="print" src="' + ps[1].src + '" alt=""><figcaption><b>2001</b>Sold, and changed by the new owner.</figcaption></figure>' +
    '</div>');
}

/* 4 — a section of their own */
function modeGallery(){
  var kq = document.querySelector(".kq");
  kq.insertAdjacentHTML("afterend",
    '<section class="pgal"><div class="films-hd"><h2>The photographs</h2>' +
    '<span class="c">' + PHOTOS.length + ' kept</span></div><div class="pgrid">' +
    PHOTOS.map(function(p){ return plate(p); }).join("") + '</div></section>');
}

/* 5 — against the record */
function modeRecord(){
  var rec = document.getElementById("rec"); if(!rec) return;
  rec.insertAdjacentHTML("afterend",
    '<figure class="pbeside"><img class="print" src="' + PHOTOS[0].src + '" alt="">' +
    '<figcaption><b>The house &middot; Kanpur</b>' + PHOTOS[0].cap + '</figcaption></figure>');
}

/* 6 — hanging off the pin on the map */
function modeMap(){
  var map = document.getElementById("map"); if(!map) return;
  map.insertAdjacentHTML("beforeend",
    '<figure class="ppin"><img class="print" src="' + PHOTOS[0].src + '" alt="">' +
    '<figcaption><b>Pin 1 &middot; where he grew up</b>The house, before it was sold.</figcaption></figure>');
}

/* 7 — press one and it fills the screen */
function modeLightbox(){
  modeGallery();
  var box = document.createElement("div");
  box.className = "lbox"; box.hidden = true;
  box.innerHTML = '<button class="x" aria-label="Close">&times;</button>' +
    '<button class="nav prev" aria-label="Previous">&larr;</button>' +
    '<figure><img alt=""><figcaption><b></b><span></span></figcaption>' +
    '<p class="of"></p></figure>' +
    '<button class="nav next" aria-label="Next">&rarr;</button>';
  document.body.appendChild(box);
  var img = box.querySelector("img"), wn = box.querySelector("b"),
      cp = box.querySelector("figcaption span"), of = box.querySelector(".of"), at = 0;

  function show(i){
    at = (i + PHOTOS.length) % PHOTOS.length;
    var p = PHOTOS[at];
    img.src = p.src; wn.textContent = p.when; cp.textContent = p.cap;
    of.textContent = (at + 1) + " of " + PHOTOS.length;
    box.hidden = false;
  }
  document.querySelectorAll(".pgrid .print").forEach(function(el, i){
    el.style.cursor = "zoom-in";
    el.addEventListener("click", function(){ show(i); });
  });
  box.querySelector(".x").addEventListener("click", function(){ box.hidden = true; });
  box.querySelector(".prev").addEventListener("click", function(){ show(at - 1); });
  box.querySelector(".next").addEventListener("click", function(){ show(at + 1); });
  box.addEventListener("click", function(e){ if(e.target === box) box.hidden = true; });
  addEventListener("keydown", function(e){
    if(box.hidden) return;
    if(e.key === "Escape") box.hidden = true;
    if(e.key === "ArrowRight") show(at + 1);
    if(e.key === "ArrowLeft") show(at - 1);
  });
}

var MODES = [modeCard, modePlate, modePair, modeGallery, modeRecord, modeMap, modeLightbox];
function applyPhotos(n){
  try { MODES[n - 1](); } catch(e) { console.error("photo mode " + n, e); }
  if(typeof layoutGrid === "function") setTimeout(layoutGrid, 60);
}
