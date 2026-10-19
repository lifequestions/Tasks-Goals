/* Draws the homepage from home-data.js.

   The rule throughout: where a fact is missing, say so. An empty city list
   says there are no cities listed yet rather than showing a plausible one,
   and a missing film says there is no film rather than a broken player. */

function esc(t){
  return String(t == null ? "" : t)
    .replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}
function has(v){ return typeof v === "string" ? v.trim() !== "" : !!v; }

/* Pages in a sub-folder — /events/ — set ASSET_BASE to "../" so that the file
   names in home-data.js keep resolving against the root of the site. */
function asset(f){
  var base = (typeof ASSET_BASE === "string") ? ASSET_BASE : "";
  return /^(https?:)?\/\//.test(f) ? f : base + f;
}

/* ---- cities ----
   A photograph of the place, the name over it, and the next date. If the
   photograph is missing, or fails to load, the card falls back to the name on
   a tint rather than showing a broken image. */
function drawCities(){
  var host = document.getElementById("cityList");
  if(!host) return;
  var live = (typeof CITIES !== "undefined" ? CITIES : []).filter(function(c){ return has(c.city); });
  if(!live.length){
    host.innerHTML = '<p class="empty">No cities listed yet.</p>';
    return;
  }
  var g = document.createElement("div");
  g.className = "cities";

  live.forEach(function(c){
    var el = document.createElement(has(c.link) ? "a" : "div");
    el.className = "city" + (has(c.photo) ? "" : " flat");
    if(has(c.link)){ el.href = c.link; el.target = "_blank"; el.rel = "noopener"; }

    var slug = c.city.toLowerCase().replace(/\s+/g, "-");
    var art  = (typeof CITY_ART !== "undefined") ? CITY_ART[slug] : null;

    var inner = "";
    if(has(c.photo)) inner += '<img src="' + esc(asset(c.photo)) + '" alt="' + esc(c.city) + '" loading="lazy">';
    else if(art)     inner += '<span class="art">' + art + "</span>";
    inner += '<span class="veil"></span><span class="txt">';
    if(has(c.country)) inner += '<span class="co">' + esc(c.country) + "</span>";
    inner += "<h3>" + esc(c.city) + "</h3>";
    inner += '<span class="next">' + (has(c.next) ? esc(c.next) : "Next date to be announced") + "</span>";
    if(has(c.where)) inner += '<span class="next">' + esc(c.where) + "</span>";
    if(has(c.link))  inner += '<span class="go">Book a place &rarr;</span>';
    inner += "</span>";
    el.innerHTML = inner;

    /* A photograph that never arrives gives way to the drawing. */
    var img = el.querySelector("img");
    if(img) img.addEventListener("error", function(){
      img.remove();
      el.classList.add("flat");
      if(art) el.insertAdjacentHTML("afterbegin", '<span class="art">' + art + "</span>");
    });

    g.appendChild(el);
  });

  host.innerHTML = "";
  host.appendChild(g);
}

/* ---- the film ----
   A still and a play button, with the YouTube player loaded only when it is
   pressed. Nothing is requested from YouTube until somebody asks for it. */
function drawFilm(){
  var host = document.getElementById("filmBox"),
      f = typeof FILM !== "undefined" ? FILM : {};
  if(!host) return;
  if(!has(f.id)){
    host.innerHTML = '<div class="film none"><p>No film here yet.</p></div>';
    return;
  }
  var a = document.createElement("button");
  a.className = "film";
  a.setAttribute("aria-label", "Play the film");
  a.innerHTML = '<img src="https://i.ytimg.com/vi/' + esc(f.id) + '/hqdefault.jpg" alt="">' +
                '<span class="sh"></span><span class="play"></span>';
  a.addEventListener("click", function(){
    a.innerHTML = '<iframe src="https://www.youtube-nocookie.com/embed/' + esc(f.id) +
      '?autoplay=1&rel=0" title="Life Questions" allow="accelerometer; autoplay; encrypted-media; ' +
      'picture-in-picture; fullscreen" allowfullscreen></iframe>';
    a.style.cursor = "default";
  }, { once:true });
  host.innerHTML = "";
  host.appendChild(a);
  if(has(f.caption)){
    var p = document.createElement("p");
    p.className = "filmcap";
    p.textContent = f.caption;
    host.appendChild(p);
  }
}

/* ---- who started it ---- */
function drawTeam(){
  var host = document.getElementById("teamList");
  if(!host) return;
  var who = (typeof TEAM !== "undefined" ? TEAM : []).filter(function(p){ return has(p.name); });
  if(!who.length){
    var sec = document.getElementById("who");
    if(sec) sec.style.display = "none";
    return;
  }
  host.innerHTML = "";
  who.forEach(function(p){
    var el = document.createElement("div");
    el.className = "who";
    var initials = p.name.split(/\s+/).map(function(w){ return w.charAt(0); }).join("").slice(0,2);
    el.innerHTML =
      '<div class="face">' + (has(p.photo)
        ? '<img src="' + esc(asset(p.photo)) + '" alt="' + esc(p.name) + '">'
        : esc(initials.toUpperCase())) + "</div>" +
      "<h3>" + esc(p.name) + "</h3>" +
      (has(p.role) ? '<p class="role">' + esc(p.role) + "</p>" : "") +
      (has(p.bio)  ? "<p>" + esc(p.bio) + "</p>" : "");
    host.appendChild(el);
  });
}

/* ---- email ----
   The address is written into the links at load rather than sitting in the
   HTML, which keeps the simplest address scrapers off it. */
function drawMail(){
  var to = (typeof CONTACT !== "undefined" && has(CONTACT.email)) ? CONTACT.email.trim() : "";
  [["hostMail",  "A Life Questions evening in my city"],
   ["closeMail", "Life Questions"],
   ["footMail",  "Life Questions"]].forEach(function(pair){
    var el = document.getElementById(pair[0]);
    if(!el) return;
    if(!to){ el.textContent = "Email address to come"; el.removeAttribute("href"); return; }
    el.href = "mailto:" + to + "?subject=" + encodeURIComponent(pair[1]);
    if(pair[0] === "footMail") el.textContent = to;
  });
}

/* ---- the channel ---- */
function drawChannel(){
  var el = document.getElementById("channelLink"),
      f = typeof FILM !== "undefined" ? FILM : {};
  if(!el) return;
  if(!has(f.channel)){ el.parentNode.style.display = "none"; return; }
  el.href = f.channel;
  el.target = "_blank";
  el.rel = "noopener";
}

/* ---- social accounts ---- */
function drawSocial(){
  var host = document.getElementById("social");
  if(!host) return;
  var list = (typeof SOCIAL !== "undefined" ? SOCIAL : []).filter(function(a){ return has(a.url); });
  if(!list.length){ host.style.display = "none"; return; }
  host.innerHTML = list.map(function(a){
    var mark = (typeof iconSvg === "function") ? iconSvg(a.icon || a.name) : "";
    return '<a href="' + esc(a.url) + '" target="_blank" rel="noopener" title="' + esc(a.name) +
           '" aria-label="' + esc(a.name) + '">' + (mark || esc(a.name)) + "</a>";
  }).join("");
}

/* ---- where the evenings are booked ---- */
function drawMeetup(){
  var url = (typeof MEETUP !== "undefined" && has(MEETUP)) ? MEETUP : "";
  [].forEach.call(document.querySelectorAll("[data-meetup]"), function(el){
    if(!url){ el.style.display = "none"; return; }
    el.href = url; el.target = "_blank"; el.rel = "noopener";
  });
}

drawCities();
drawSocial();
drawMeetup();
drawFilm();
drawChannel();
drawTeam();
drawMail();
