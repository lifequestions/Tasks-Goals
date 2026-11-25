# Prompt for ChatGPT — redesign cognitivebiases.co

Paste everything below the line. It is self-contained. Give ChatGPT browsing — the
prompt asks it to open four URLs and it is much weaker without them.

---

You are a senior product designer and front-end engineer. I want you to redesign a
website. Before you write anything, open these pages and actually look at them. Do not
work from memory of any of them.

**The site to redesign**

- https://www.cognitivebiases.co/ — the home page
- https://www.cognitivebiases.co/decision-biases.html — an inner page
- https://www.cognitivebiases.co/money-risk.html — another inner page

**The two references I want it to feel like**

- https://stripe.press/ — for its restraint, its typography and the confidence of its index page
- https://www.coglode.com/nuggets — for how it indexes many small items and makes each one feel like an object worth collecting

## What the site is

A reference library of cognitive biases, presented as a deck of cards. Each bias is one
card. There are six categories, each with its own colour:

| key | name | subtitle | colour |
|---|---|---|---|
| money | Money & Risk | Bad Bets & Irrational Risk | `#4f46e5` |
| power | Power & Leadership | Negotiation & Influence | `#be185d` |
| social | Social & Relationships | Judgement & Tribal Thinking | `#047857` |
| ego | Self-Deception | Ego Protection | `#c2410c` |
| narrative | Narrative & Information | Media & Data Distortion | `#b45309` |
| speed | Decision Speed | Action & Urgency Biases | `#0e7490` |

Each bias is one record with this exact shape:

```js
{ name: 'Loss Aversion',
  category: 'money',
  description: 'Losses hurt about twice as much as equivalent gains feel good.',
  example: 'Holding a losing stock for months hoping it recovers rather than cutting losses.',
  related: ['Endowment Effect', 'Sunk Cost Fallacy'] }
```

Some records also carry `howItWorks` (why the bias happens) and `overcome` (an array of
`{title, text}` counter-moves). Most do not yet.

## What is there now, and what is wrong with it

I checked these against the live code and a rendered screenshot, so they are facts, not
impressions.

**Home page.** A hero reading "Bias Cards", a fan of six overlapping category cards, a
section headed "All 43 Biases" holding a circle of small coloured dots with a legend, then
a "Get the physical deck" button that fires `alert('Coming soon!')`.

- The fan overlaps so hard that four of the six names are cut off mid-word: "Money & R…",
  "Social & Relationship…", "Self-Decep…", "Narrative & Informatio…".
- The category cards are gradient-filled with a glossy highlight. This is the single thing
  that dates the page most.

**Inner pages — this is what I most want fixed.** They are not consistent with each other:

- `openCategory()` contains `const subpages = { money: 'money-risk.html' }`. So clicking
  **Money & Risk** leaves the app and loads a hand-written static page that has **3 biases
  hard-coded in the HTML, while the data file holds 8 for that category**. Five of the
  eight are simply missing from the live site.
- A second static page, `decision-biases.html`, exists in the repo but is not in that map,
  so nothing links to it. It is orphaned.
- The other five categories render from JavaScript and do show all their biases.

So one category is a stale fork, one page is dead, and five are generated. Decide what the
inner page should be and make all six the same thing.

**The card.** Each is a flip card. Front: an illustration on a tinted panel, a category
badge, the bias name, the description, and a "Click to flip" affordance. Back: a gradient
header with the name, then three labelled blocks — "What it is", "Example", "Related
Biases" — and a "Click to flip back" hint.

- `.flip-card` is set to `aspect-ratio: 0.68`, a fixed shape regardless of content. Short
  descriptions leave a large blank area at the bottom of the card. Look at the live page
  and you will see it immediately.
- Front and back both lead with the same `description` sentence, so flipping often tells
  you nothing new.
- The category badge is repeated on every card — eight identical "POWER & LEADERSHIP"
  pills on a page whose heading already says "Power & Leadership Biases".
- The illustrations are drawn in a pale tint of the category colour on a paler tint of the
  same colour. At a glance they read as empty space.
- The flip is a dead end. There is no way from a card to a related bias, no way to step to
  the next one, and no way to link to one: nothing on the site has a URL below the
  category level.

## What I want from you

**1. A critique, written as an engineer would write it.** Name specific elements and say
what is wrong with each. Do not pad it with praise. If something on the current site is
working, say so in one line and move on.

**2. A design direction**, stated as decisions rather than adjectives. I want to read
"body text goes to a serif at 19px/1.65, measure capped at 68 characters", not "elegant
and readable". Cover at minimum: typeface pairing with named fonts and weights, a type
scale in px, the background and ink colours as hex, how the six category colours are used
once gradients are gone, border radius, shadow policy, grid and gutter, and the spacing
scale.

**3. A specific answer on the card.** This is the centre of the site. Tell me what the
card should carry on each face, in what order, at what weight, and what the reader should
be able to do from it. If you think the flip should go, say so and say what replaces it.

**4. The inner page.** Propose its structure top to bottom. Decide whether a single bias
gets its own URL, and if so what is on that page.

**5. Working code.** Produce a complete, standalone `index.html` for the home page and a
complete, standalone page for one category, both rendering real content, not lorem. These
must run by opening the file — no build step, no bundler, no framework, no npm. Vanilla
HTML, CSS and JS in one file each. Google Fonts via `<link>` is fine; nothing else
external.

**Hard constraints, because the site has to keep working:**

- Static files on Cloudflare Pages. No server, no database, no API.
- Keep the data shape above exactly. I have 52 records in it and will not be remodelling
  them for a redesign.
- Keep the six category keys and their names. You may change the hex values; say so
  explicitly if you do.
- Must work at 390px wide. The current fan does not.
- No `alert()`. If a control has nothing behind it yet, make it say so honestly on the
  page rather than pretending.
- Accessible: real `<button>` and `<a>` elements, visible focus rings, text contrast at
  4.5:1 or better against its own background.

**What to take from each reference, and what not to:**

From stripe.press, take the restraint and the typographic confidence — how much it trusts
a single well-set heading and how little chrome it uses. Do not copy its book renders or
its specific palette.

From coglode.com/nuggets, take how it makes a long index of small items feel browsable
and how each item reads as a discrete object. Do not copy its illustration style or its
colours.

I want the result to look like neither site. Take the principles, name them, and apply
them to a deck of cards about cognitive biases.

**Finally, tell me what you would cut.** The site has accumulated parts. Name anything you
think should not exist, and why.
