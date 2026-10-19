/* Everything on the homepage that is a fact about Life Questions lives here,
   so that adding a city or changing an email is one line in one file.

   Nothing here is invented. Where a value is empty the page says so plainly
   rather than showing something that looks real and isn't. The cities, the
   film and the social accounts all come from the channel's own description
   of the events video. */

/* `next` is free text — "Thursday 6 November, 7pm" or "Monthly, first
   Tuesday" — and `link` is where to book, or "" for none.
   `photo` is a file in this folder. Drop a photograph in with the name
   below and it appears — no code change needed. Something from a past
   evening, or the street the evening is held on, beats a stock skyline. */
var CITIES = [
  { city:"Amsterdam",    country:"Netherlands", photo:"city-amsterdam.jpg",    next:"", where:"", link:"" },
  { city:"Lisbon",       country:"Portugal",    photo:"city-lisbon.jpg",       next:"", where:"", link:"" },
  { city:"Gran Canaria", country:"Spain",       photo:"city-gran-canaria.jpg", next:"", where:"", link:"" }
];

/* The film that shows what an evening is like. `id` is the part of a YouTube
   address after watch?v= or youtu.be/. */
var FILM = {
  id: "n7-Pc2NYbXw",
  caption: "Events in Amsterdam, Lisbon and Gran Canaria.",
  channel: ""     /* the full youtube.com/@… address for the channel */
};

/* Where the evenings are booked. */
var MEETUP = "";

/* Who started it. photo is a file in this folder, or "" for initials. */
var TEAM = [
  // { name:"", role:"", photo:"", bio:"" },
];

var SOCIAL = [
  { name:"Instagram", url:"https://www.instagram.com/crowdwisdomco/" },
  { name:"X",         url:"https://x.com/CrowdWisdomCo" },
  { name:"TikTok",    url:"https://www.tiktok.com/@crowdwisdom" }
];

var CONTACT = { email:"" };
