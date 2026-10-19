/* A drawing for each city, used until a photograph takes its place.

   An empty card is the one thing worse than a stock skyline, and the cities
   are what the page is for. So each gets a flat, hand-cut scene in the one
   accent colour at different strengths — a canal row for Amsterdam, a
   stepped hillside and a tram for Lisbon, dunes and Roque Nublo for Gran
   Canaria. They read at card size, they sit together as a set, and nobody
   mistakes them for a photograph of a place they could stand in.

   Keyed by the city name, lowercased with spaces turned to hyphens. A city
   with no drawing here falls back to the plain tint, which is still fine. */

var CITY_ART = {

"amsterdam":
'<svg viewBox="0 0 400 500" preserveAspectRatio="xMidYMax slice" aria-hidden="true">' +
  /* sky */
  '<circle cx="312" cy="96" r="34" fill="currentColor" opacity=".10"/>' +
  /* the canal row: five narrow houses, each with its own gable */
  '<g fill="currentColor">' +
    /* step gable */
    '<path opacity=".30" d="M34 352V214h14v-12h14v-12h14v12h14v12h14v138z"/>' +
    /* bell gable */
    '<path opacity=".42" d="M110 352V196c0-26 14-34 26-34s26 8 26 34v156z"/>' +
    /* tall triangle */
    '<path opacity=".26" d="M170 352V190l32-34 32 34v162z"/>' +
    /* neck gable */
    '<path opacity=".46" d="M242 352V218h12v-20h20v20h12v134z"/>' +
    /* flat cornice */
    '<path opacity=".22" d="M302 352V236h64v116z"/>' +
    '<rect opacity=".34" x="296" y="226" width="76" height="12" rx="2"/>' +
  '</g>' +
  /* windows, as holes of light */
  '<g fill="currentColor" opacity=".14">' +
    '<rect x="44" y="236" width="12" height="18"/><rect x="66" y="236" width="12" height="18"/>' +
    '<rect x="88" y="236" width="12" height="18"/><rect x="44" y="276" width="12" height="18"/>' +
    '<rect x="66" y="276" width="12" height="18"/><rect x="88" y="276" width="12" height="18"/>' +
    '<rect x="122" y="228" width="14" height="20"/><rect x="146" y="228" width="14" height="20"/>' +
    '<rect x="122" y="272" width="14" height="20"/><rect x="146" y="272" width="14" height="20"/>' +
    '<rect x="184" y="236" width="14" height="20"/><rect x="208" y="236" width="14" height="20"/>' +
    '<rect x="184" y="280" width="14" height="20"/><rect x="208" y="280" width="14" height="20"/>' +
    '<rect x="252" y="246" width="14" height="20"/><rect x="276" y="246" width="14" height="20"/>' +
    '<rect x="252" y="288" width="14" height="20"/><rect x="276" y="288" width="14" height="20"/>' +
    '<rect x="312" y="256" width="16" height="22"/><rect x="340" y="256" width="16" height="22"/>' +
    '<rect x="312" y="298" width="16" height="22"/><rect x="340" y="298" width="16" height="22"/>' +
  '</g>' +
  /* quay, water, and the row again upside down */
  '<rect x="0" y="352" width="400" height="6" fill="currentColor" opacity=".40"/>' +
  '<rect x="0" y="358" width="400" height="142" fill="currentColor" opacity=".13"/>' +
  '<g fill="currentColor" opacity=".10">' +
    '<path d="M34 358v96h70v-96z"/><path d="M110 358v104h52v-104z"/>' +
    '<path d="M170 358v88h64v-88z"/><path d="M242 358v98h44v-98z"/>' +
    '<path d="M302 358v84h64v-84z"/>' +
  '</g>' +
  '<g fill="currentColor" opacity=".20">' +
    '<rect x="24" y="386" width="120" height="4" rx="2"/>' +
    '<rect x="188" y="410" width="150" height="4" rx="2"/>' +
    '<rect x="60" y="436" width="96" height="4" rx="2"/>' +
    '<rect x="230" y="462" width="120" height="4" rx="2"/>' +
  '</g>' +
'</svg>',

"lisbon":
'<svg viewBox="0 0 400 500" preserveAspectRatio="xMidYMax slice" aria-hidden="true">' +
  '<circle cx="86" cy="86" r="30" fill="currentColor" opacity=".10"/>' +
  /* the hill, stepping up to the right */
  '<path d="M0 500V358c58-16 108-50 152-96s92-104 152-142c30-20 60-33 96-40v320z" fill="currentColor" opacity=".10"/>' +
  /* terraced houses climbing it */
  '<g fill="currentColor">' +
    '<path opacity=".40" d="M28 420v-60l26-16 26 16v60z"/>' +
    '<path opacity=".28" d="M92 404v-74l28-18 28 18v74z"/>' +
    '<path opacity=".46" d="M160 388v-86l30-20 30 20v86z"/>' +
    '<path opacity=".26" d="M232 372v-98l30-20 30 20v98z"/>' +
    '<path opacity=".38" d="M304 356v-112l32-22 32 22v112z"/>' +
  '</g>' +
  '<g fill="currentColor" opacity=".13">' +
    '<rect x="42" y="372" width="12" height="16"/><rect x="60" y="372" width="12" height="16"/>' +
    '<rect x="104" y="348" width="14" height="18"/><rect x="124" y="348" width="14" height="18"/>' +
    '<rect x="172" y="320" width="14" height="20"/><rect x="196" y="320" width="14" height="20"/>' +
    '<rect x="172" y="352" width="14" height="20"/><rect x="196" y="352" width="14" height="20"/>' +
    '<rect x="244" y="292" width="14" height="20"/><rect x="268" y="292" width="14" height="20"/>' +
    '<rect x="244" y="326" width="14" height="20"/><rect x="268" y="326" width="14" height="20"/>' +
    '<rect x="316" y="264" width="16" height="22"/><rect x="342" y="264" width="16" height="22"/>' +
    '<rect x="316" y="300" width="16" height="22"/><rect x="342" y="300" width="16" height="22"/>' +
  '</g>' +
  /* the street, and a tram on it */
  '<rect x="0" y="420" width="400" height="80" fill="currentColor" opacity=".16"/>' +
  '<g fill="currentColor">' +
    '<path opacity=".55" d="M58 452h126c6 0 10 4 10 10v30c0 6-4 10-10 10H58c-6 0-10-4-10-10v-30c0-6 4-10 10-10z"/>' +
    '<rect opacity=".14" x="62" y="462" width="30" height="20" rx="2"/>' +
    '<rect opacity=".14" x="100" y="462" width="30" height="20" rx="2"/>' +
    '<rect opacity=".14" x="138" y="462" width="30" height="20" rx="2"/>' +
    '<rect opacity=".40" x="114" y="430" width="4" height="22"/>' +
    '<rect opacity=".40" x="86" y="428" width="64" height="4" rx="2"/>' +
  '</g>' +
  '<rect x="0" y="494" width="400" height="3" fill="currentColor" opacity=".34"/>' +
'</svg>',

"gran-canaria":
'<svg viewBox="0 0 400 500" preserveAspectRatio="xMidYMax slice" aria-hidden="true">' +
  '<circle cx="300" cy="104" r="38" fill="currentColor" opacity=".13"/>' +
  /* the far ridge */
  '<path d="M0 320l78-76 52 42 44-32 66 54 56-44 104 72v164H0z" fill="currentColor" opacity=".14"/>' +
  /* Roque Nublo: the monolith, and the smaller finger beside it */
  '<path d="M150 356V212c0-16 8-26 22-26s22 10 22 26v144z" fill="currentColor" opacity=".50"/>' +
  '<path d="M206 356v-96c0-12 5-18 12-18s12 6 12 18v96z" fill="currentColor" opacity=".34"/>' +
  /* dunes, three overlapping crests */
  '<path d="M0 500V404c64-34 120-30 176 4s112 44 224 8v84z" fill="currentColor" opacity=".22"/>' +
  '<path d="M0 500V446c70-28 126-18 180 10s134 26 220-6v50z" fill="currentColor" opacity=".32"/>' +
  '<path d="M0 500v-28c76-22 140-6 196 14s130 12 204-10v24z" fill="currentColor" opacity=".44"/>' +
  /* wind lines on the sand */
  '<g fill="none" stroke="currentColor" opacity=".18" stroke-width="3" stroke-linecap="round">' +
    '<path d="M40 424c40-16 84-14 122 4"/>' +
    '<path d="M214 442c44 14 92 12 140-8"/>' +
    '<path d="M72 470c52-14 104-6 148 12"/>' +
  '</g>' +
'</svg>'

};
