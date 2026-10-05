/* The send sheet.

   Everything personal lives in this browser and nowhere else. The repository
   is public, so a phone number must never reach it; localStorage is the only
   store, and it holds the numbers, the week each person is on, and the dates
   things went out and came back.

   The WhatsApp link is wa.me, which is Meta's own deep link: on a phone it
   opens the app, on a desktop it opens WhatsApp Web or the desktop app. It
   takes the number as digits only, with the country code and no leading zero.
   For people who do not use WhatsApp — most Americans — the same message goes
   out as a mailto: link instead, which opens their mail app the same way. */

var KEY = "lq.send.v1";

function load(){
  try { return JSON.parse(localStorage.getItem(KEY) || "{}") || {}; }
  catch(e){ return {}; }
}
function save(s){
  try { localStorage.setItem(KEY, JSON.stringify(s)); } catch(e){}
}
var STATE = load();

function mine(name){
  if(!STATE[name]) STATE[name] = {};
  return STATE[name];
}
function weekOf(p){
  var s = mine(p.name);
  return s.week || p.week || 1;
}
function question(n){
  for(var i=0;i<WEEKS.length;i++) if(WEEKS[i].n === n) return WEEKS[i];
  return null;
}
function esc(t){
  return String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
}
function today(){
  return new Date().toISOString().slice(0,10);
}
function pretty(iso){
  if(!iso) return "";
  var d = new Date(iso + "T12:00:00");
  return d.toLocaleDateString(undefined,{day:"numeric",month:"short"});
}

/* wa.me wants digits only: no plus, no spaces, no brackets. A leading zero is
   a national trunk code and has to go, but only once we have a country code to
   put in its place — so we leave it and warn rather than guessing the country. */
function digits(tel){
  return String(tel||"").replace(/[^\d]/g,"");
}
function telWarning(tel){
  var d = digits(tel);
  if(!d) return "";
  if(d.charAt(0) === "0")
    return "That starts with a 0. WhatsApp needs the country code instead — 44 for the UK, so 07… becomes 447….";
  if(d.length < 8) return "That looks short for a full international number.";
  return "";
}

function card(p){
  var s   = mine(p.name),
      n   = weekOf(p),
      w   = question(n),
      sent= (s.sent || {})[n],
      cold= !s.tel && !s.email,
      el  = document.createElement("article");

  el.className = "pc" + (sent ? " done" : "") + (cold ? " cold" : "");

  var bits = [];
  if(p.where)   bits.push(p.where);
  if(p.channel) bits.push(p.channel);
  bits.push("Question " + n + " of 52");


  var h = '<div class="top"><h2>' + esc(p.name) + '</h2>' +
          '<p class="meta">' + esc(bits.join(" \u00b7 ")) +
          (p.page ? ' \u00b7 <a href="' + p.page + '" target="_blank" rel="noopener">their page</a>' : '') +
          '</p></div>';

  if(p.note) h += '<p class="note">' + esc(p.note) + '</p>';

  if(w){
    h += '<div class="wk">' +
         '<p class="wkn">' + esc(w.season) + '</p>' +
         '<p class="q">' + esc(w.q) + '</p>';
    if(w.spare)
      h += '<details class="spare"><summary>If they dry up</summary><p>' + esc(w.spare) + '</p></details>';
    h += '</div>';
  } else {
    h += '<div class="wk"><p class="q">All fifty-two answered.</p></div>';
  }

  h += '<div class="acts">';
  if(w){
    h += '<a class="btn" data-go="wa" href="#">Send on WhatsApp</a>' +
         '<a class="btn ghost" data-go="em" href="#">Send by email</a>' +
         '<button class="lnk" data-act="show">Read the message</button>';
    h += sent
      ? '<span class="said">Sent ' + pretty(sent) + '</span>' +
        '<button class="lnk" data-act="answered">Answered &rarr; next question</button>' +
        '<button class="lnk" data-act="unsent">Undo</button>'
      : '<button class="lnk" data-act="sent">Mark sent</button>';
  }
  h += '<button class="lnk" data-act="contact">' + (cold ? "Add number" : "Change number") + '</button>';
  if(n > 1) h += '<button class="lnk" data-act="back">Back a question</button>';
  h += '</div>';

  h += '<div class="contact' + (cold ? " open" : "") + '">' +
       '<label><span>WhatsApp number</span><input data-f="tel" inputmode="tel" ' +
         'placeholder="447700900123" value="' + esc(s.tel || "") + '"></label>' +
       '<label><span>Email instead</span><input data-f="email" inputmode="email" ' +
         'placeholder="name@example.com" value="' + esc(s.email || "") + '"></label>' +
       '<p class="hint">Country code, digits only, no plus and no leading zero. ' +
         'UK 44, United States 1, Germany 49.</p></div>';

  h += '<div class="msgbox"><textarea readonly>' + esc(w ? w.msg : "") + '</textarea></div>';

  el.innerHTML = h;
  wire(el, p);
  return el;
}

function wire(el, p){
  var s = mine(p.name);

  function redraw(){
    save(STATE);
    var fresh = card(p);
    el.parentNode.replaceChild(fresh, el);
  }

  [].forEach.call(el.querySelectorAll(".contact input"), function(inp){
    inp.addEventListener("input", function(){
      s[inp.dataset.f] = inp.value.trim();
      save(STATE);
      var hint = el.querySelector(".contact .hint");
      if(inp.dataset.f === "tel"){
        var warn = telWarning(inp.value);
        hint.textContent = warn ||
          "Country code, digits only, no plus and no leading zero. UK 44, United States 1, Germany 49.";
        hint.style.color = warn ? "var(--acc)" : "";
      }
    });
  });

  [].forEach.call(el.querySelectorAll("[data-act]"), function(b){
    b.addEventListener("click", function(){
      var a = b.dataset.act, n = weekOf(p);
      if(a === "contact"){      el.querySelector(".contact").classList.toggle("open"); return; }
      if(a === "show"){     el.querySelector(".msgbox").classList.toggle("open"); return; }
      if(a === "sent"){     s.sent = s.sent || {}; s.sent[n] = today(); }
      if(a === "unsent"){   if(s.sent) delete s.sent[n]; }
      if(a === "answered"){ s.answered = s.answered || {}; s.answered[n] = today(); s.week = n + 1; }
      if(a === "back"){     s.week = n - 1; }
      redraw();
    });
  });

  [].forEach.call(el.querySelectorAll("[data-go]"), function(a){
    a.addEventListener("click", function(ev){
      ev.preventDefault();
      var n = weekOf(p), w = question(n);
      if(!w) return;
      var text = encodeURIComponent(w.msg), url;
      if(a.dataset.go === "wa"){
        var d = digits(s.tel);
        if(!d){
          el.querySelector(".contact").classList.add("open");
          el.querySelector('.contact [data-f="tel"]').focus();
          return;
        }
        url = "https://wa.me/" + d + "?text=" + text;
      } else {
        if(!s.email){
          el.querySelector(".contact").classList.add("open");
          el.querySelector('.contact [data-f="email"]').focus();
          return;
        }
        url = "mailto:" + encodeURIComponent(s.email) +
              "?subject=" + encodeURIComponent("A question for you — week " + n) +
              "&body=" + text;
      }
      /* Mark it sent on the way out, so that coming back from WhatsApp the
         card already shows where it got to. */
      s.sent = s.sent || {}; s.sent[n] = today();
      save(STATE);
      window.open(url, "_blank", "noopener");
      var fresh = card(p);
      el.parentNode.replaceChild(fresh, el);
    });
  });
}

function group(title, people, host){
  if(!people.length) return;
  var g = document.createElement("div");
  g.className = "grp";
  g.innerHTML = '<p class="mo">' + esc(title) + '</p>';
  host.appendChild(g);
  people.forEach(function(p){ g.appendChild(card(p)); });
}

function draw(){
  var host = document.getElementById("list");
  host.innerHTML = "";
  var going = [], waiting = [];
  PEOPLE.forEach(function(p){
    var s = mine(p.name);
    (s.tel || s.email ? going : waiting).push(p);
  });
  group("Recording", going, host);
  group("Not started — no number yet", waiting, host);
}

(function(){
  var d = new Date();
  document.getElementById("today").textContent =
    d.toLocaleDateString(undefined,{weekday:"long",day:"numeric",month:"long"});
  draw();
})();
