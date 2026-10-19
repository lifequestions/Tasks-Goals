/* Simplified marks for the accounts we link to, drawn as paths so they take
   the page's colour and stay sharp at any size — four small images would be
   four more requests and would not follow the theme. */
var ICONS = {

"instagram":
 '<rect x="3" y="3" width="18" height="18" rx="5.2" fill="none" stroke="currentColor" stroke-width="1.7"/>' +
 '<circle cx="12" cy="12" r="4.1" fill="none" stroke="currentColor" stroke-width="1.7"/>' +
 '<circle cx="17.3" cy="6.7" r="1.25" fill="currentColor"/>',

"x":
 '<path fill="currentColor" d="M18.9 2.3h3.1l-6.8 7.8 8 10.6h-6.3l-4.9-6.4-5.6 6.4H3.3l7.3-8.4-7.7-10h6.4l4.5 5.9 5.1-5.9zm-1.1 16.5h1.7L7.3 4.1H5.5l12.3 14.7z"/>',

"tiktok":
 '<path fill="currentColor" d="M16.3 2.4h-3.1v13a2.6 2.6 0 1 1-2.1-2.6V9.6a5.8 5.8 0 1 0 5.2 5.8V8.9a7 7 0 0 0 4.2 1.4V7.2a4.1 4.1 0 0 1-4.2-4.1 4 4 0 0 1 0-.7z"/>',

"youtube":
 '<path fill="currentColor" d="M22.5 7.4a2.8 2.8 0 0 0-1.9-2C18.9 5 12 5 12 5s-6.9 0-8.6.4a2.8 2.8 0 0 0-1.9 2A29 29 0 0 0 1.1 12a29 29 0 0 0 .4 4.6 2.8 2.8 0 0 0 1.9 2C5.1 19 12 19 12 19s6.9 0 8.6-.4a2.8 2.8 0 0 0 1.9-2 29 29 0 0 0 .4-4.6 29 29 0 0 0-.4-4.6zM9.8 15.2V8.8L15.4 12l-5.6 3.2z"/>'

};

function iconSvg(name){
  var d = ICONS[String(name || "").toLowerCase()];
  if(!d) return "";
  return '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true" focusable="false">' + d + "</svg>";
}
