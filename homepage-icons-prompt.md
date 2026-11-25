# Prompt for ChatGPT — redraw the icons on cognitivebiases.co

Paste everything below the line into ChatGPT, and **attach `icon-contact-sheet.png`**
from this folder. That sheet shows all 58 icons at the exact size, and on the exact
colour, the site draws them at — it is most of the brief. Use a model with vision.

---

You are an icon designer. I want you to redraw the icon set for a website. I have
attached a contact sheet showing every current icon at the size and on the ground
colour it is actually drawn at. Look at it before you write anything.

## What the site is

cognitivebiases.co presents 52 cognitive biases as a deck of cards, in six suits.
The home page has two kinds of icon, and I want both redrawn.

**A. The 52 deck glyphs.** One per bias. Each sits in a rounded square tile filled
with its suit colour: **88px tile with a 40px glyph on desktop, 76px tile with a 35px
glyph on a phone.** White on a saturated ground. They are laid out six across, so all
52 are in view at once and get compared against each other directly. The same glyph
is reused at 38px on the card itself.

**B. The six suit marks.** One per suit. These sit on the large fan cards at the top
of the page at **41px, white at 50% opacity**, as a quiet watermark behind the suit
name. They must not compete with the name, but they must be visible.

## What is wrong with the set now

Measured from the source, not impressions.

**Nothing matches anything.** Across the 52 glyphs there are **nine different stroke
widths** — 1, 1.4, 1.5, 1.6, 1.7, 1.8, 2, 2.2 and 2.5 — and **24 of the 52 mix more
than one width inside a single icon**. Only 23 of the 52 set `stroke-linecap` at all,
so line ends are round or square apparently at random.

**Opacity is used as a shading hack.** 36 of the 52 contain a filled shape, and
`fill-opacity` / `opacity` appear at **14 different values** between 0.15 and 0.9. At
40px on a saturated ground the faint parts disappear and the icon reads as
half-drawn. Availability Cascade, Clustering Illusion, Social Comparison, Survivorship
Bias, Consistency Bias and Base Rate Neglect all have this; find them on the sheet and
you will see parts of each that are barely there.

**Icons collide.** Several pairs are effectively the same drawing:

- *Projection Bias* and *Illusory Correlation* — both two overlapping circles.
- *Dunning-Kruger Effect* and *Narrative Fallacy* — both the same squiggle.
- *Overconfidence Bias* and *Availability Heuristic* — both a clock face.
- *Escalation of Commitment*, *Social Comparison* and *Survivorship Bias* — three bar charts.
- *Recency Bias*, *Gambler's Fallacy* and *Bandwagon Effect* — three rows of dots.
- *Endowment Effect* and *Default Effect* — both a rounded rectangle inside a rounded rectangle.
- *Bystander Effect* and *Clustering Illusion* — both scattered dots around a ring.

Structurally, six of the 52 are built from exactly two circles and one path, and four
more from one circle and two paths. They read as the same icon at tile size.

**Two of the suit marks are wrong, not merely weak.** The *Decision Speed* mark is a
dollar sign — which belongs to Money & Risk, whose mark is instead an abstract dotted
square. And all six carry inline `style="animation: spin-slow …"` attributes left from
an older version of the site; **those keyframes no longer exist**, so that code is
dead. Do not reproduce it.

## What I want

52 new deck glyphs and 6 new suit marks. These constraints are not stylistic
preferences — the site breaks or looks wrong without them.

**Format.** Inline SVG only. No external references, no `<defs>`, no filters, no
gradients, no CSS, no `<text>`, no numerals or letters of any kind.

- Deck glyph: `<svg viewBox="0 0 32 32" fill="none">…</svg>`
- Suit mark: `<svg viewBox="0 0 80 80" fill="none">…</svg>`

**Colour.** The literal string `white` for every stroke and every fill. Nothing else —
no `currentColor`, no hex. The site recolours them itself.

**One visual language across all 58.** Outline-first: `stroke-width="2"` on every deck
glyph, `stroke-width="4"` on the suit marks (they are drawn in an 80-unit box at half
scale and at 50% opacity, so anything thinner vanishes), `stroke-linecap="round"` and
`stroke-linejoin="round"` throughout. Use a solid fill only where the fill carries
meaning — a weight, the option chosen, the thing kept — and then fill it at full
strength. **No `opacity` or `fill-opacity` anywhere.** If a shape needs to recede,
leave it out.

**Drawn for the size.** Legible at 35px. Keep a 2-unit margin inside the 32×32 box,
nothing thinner than 1.5 units, no feature under 3 units across, at most about six
elements per glyph. Judge each one imagining it at 35px, not at the size you are
drawing it.

**All 58 distinct.** If two biases would get the same shape, one of them is wrong —
find a different idea rather than varying the same one slightly.

**Mechanism, not subject matter.** Each glyph should name what the bias *does*, not
illustrate its topic. Sunk Cost Fallacy is not a money bag; it is something being
carried that should have been put down. Where no literal picture exists, a clear
abstract diagram of the mechanism beats a vague one.

## The six suits

| suit | subtitle | what it covers |
|---|---|---|
| Money & Risk | Bad Bets & Irrational Risk | how we handle money, investments and risk |
| Power & Leadership | Negotiation & Influence | status, framing and leverage |
| Social & Relationships | Judgement & Tribal Thinking | how we judge and relate to others |
| Self-Deception | Ego Protection | how we protect our own self-image |
| Narrative & Information | Media & Data Distortion | how stories and data mislead us |
| Decision Speed | Action & Urgency Biases | rushing, defaulting and over-acting |

A suit mark should read as the *kind of decision*, not as one bias inside it, and must
still be recognisable as a 41px watermark at half opacity.

## The 52 biases, in deck order

**Money & Risk**

 1. **Loss Aversion** — Losses hurt about twice as much as equivalent gains feel good.
 2. **Sunk Cost Fallacy** — Continuing an endeavor because of past investment rather than evaluating its current or future value.
 3. **Anchoring Bias** — The tendency to rely too heavily on the first piece of information encountered when making decisions.
 4. **Overconfidence Bias** — Excessive confidence in your own answers, predictions, and abilities beyond what the evidence supports.
 5. **Recency Bias** — Overweighting recent events while discounting older information.
 6. **Endowment Effect** — Overvaluing what you already own simply because you own it.
 7. **Disposition Effect** — Selling winners too early and holding losers too long to avoid realizing a loss.
 8. **Optimism Bias** — Overestimating positive outcomes for yourself while underestimating negative ones.
 9. **Gambler's Fallacy** — Past random results feel like they change the odds of the next one.

**Power & Leadership**

10. **Authority Bias** — Giving extra weight to authority figures even when their expertise is irrelevant.
11. **Status Quo Bias** — Preferring the current state of affairs. Changes from the baseline are perceived as a loss.
12. **Framing Effect** — Reacting differently to the same information based on whether it's framed as a gain or loss.
13. **Reactance** — Doing the opposite of what's requested when you feel your freedom is threatened.
14. **False Consensus** — Overestimating how much others share your beliefs and behaviors.
15. **Illusion of Control** — Overestimating your ability to influence events determined by chance.
16. **Escalation of Commitment** — Increasing investment in a decision despite evidence it was wrong, to justify prior choices.
17. **Halo Effect** — A positive impression in one area spills over to influence opinions in unrelated areas.
18. **Scarcity Bias** — Anything that looks like it's running out starts to look worth more.

**Social & Relationships**

19. **Attribution Error** — Blaming others' behavior on their character but your own on the situation.
20. **In-Group Bias** — Favoring members of your own group with more trust, empathy, and positive attributions.
21. **Out-Group Homogeneity** — Seeing members of other groups as more alike than they really are, while seeing your own group as diverse.
22. **Projection Bias** — Assuming others think and feel the same way you do right now.
23. **Stereotyping** — Applying generalized beliefs about a group to an individual without evidence.
24. **Social Comparison** — Evaluating yourself by comparing to others, leading to envy or false superiority.
25. **Just-World Hypothesis** — Believing people get what they deserve, leading to victim-blaming.
26. **Bystander Effect** — The more people who could step in, the less likely any one of them does.
27. **Bandwagon Effect** — Something feels more true the more people you can see believing it.

**Self-Deception**

28. **Confirmation Bias** — Searching for and favoring information that confirms preexisting beliefs while ignoring contradictory evidence.
29. **Self-Serving Bias** — Attributing success to skill and failure to bad luck, protecting self-esteem.
30. **Dunning-Kruger Effect** — Low expertise leads to overconfidence, while high expertise leads to self-doubt.
31. **Bias Blind Spot** — Recognizing cognitive biases in others but failing to see them in yourself.
32. **Consistency Bias** — Misremembering your past beliefs as being more similar to your current ones than they actually were.
33. **Hindsight Bias** — Seeing past events as predictable after the fact. The "I knew it all along" effect.
34. **Illusion of Explanatory Depth** — Believing you understand complex systems far better than you actually do.
35. **Moral Licensing** — Doing one good thing quietly buys you permission to do a worse one next.
36. **Ostrich Effect** — When the news is likely to be bad, you just don't look.

**Narrative & Information**

37. **Availability Heuristic** — Overestimating the likelihood of vivid, recent, or emotionally charged events.
38. **Survivorship Bias** — Focusing only on successes while ignoring the far more numerous failures.
39. **Narrative Fallacy** — Constructing simple stories to explain complex events, creating false cause-and-effect.
40. **Clustering Illusion** — Seeing meaningful patterns in random data where none actually exist.
41. **Illusory Correlation** — Perceiving a relationship between two unrelated things because they co-occurred.
42. **Base Rate Neglect** — Ignoring statistical base rates in favor of specific, individual information.
43. **Peak-End Rule** — Judging an experience by its most intense moment and its ending, not the average.
44. **Curse of Knowledge** — Once you know something, you can't picture what it's like not to.
45. **Availability Cascade** — A claim repeated often enough starts to feel like settled fact.

**Decision Speed**

46. **Planning Fallacy** — Underestimating time and cost while overestimating benefits, even with past experience.
47. **Action Bias** — Preferring to do something rather than nothing, even when inaction would be more effective.
48. **Default Effect** — Sticking with the pre-selected option because changing requires effort.
49. **Decoy Effect** — A third "decoy" option shifts preference toward one of the original two by making it look better.
50. **Hyperbolic Discounting** — Preferring smaller immediate rewards over larger future ones, disproportionately.
51. **Choice Overload** — Past a certain point, more options make it harder to pick any of them.
52. **Zero-Risk Bias** — Wiping out one small risk entirely beats halving a much bigger one.
## How to hand it back

One fenced JavaScript block, nothing else inside it, in exactly this shape so I can
paste it straight into the source:

```js
const MINI_ICONS = {
  'Loss Aversion': `<svg viewBox="0 0 32 32" fill="none">…</svg>`,
  'Sunk Cost Fallacy': `<svg viewBox="0 0 32 32" fill="none">…</svg>`,
  // … all 52, keyed by the exact names above, in the order above
};

const SUIT_MARKS = {
  money: `<svg viewBox="0 0 80 80" fill="none">…</svg>`,
  power: `…`, social: `…`, ego: `…`, narrative: `…`, speed: `…`,
};
```

The names must match character for character, apostrophes included, or the lookup
fails.

Then, outside the code block and in no more than fifteen lines: the rule you settled
on for when a shape is filled rather than outlined, and any icons you are not happy
with, and why.

## Before you start

Do not give me a plan, a mood board, or a description of what you intend to draw.
Draw them. If something here is genuinely impossible — if you cannot make 52 distinct
legible glyphs under these constraints — say which ones and why, *after* you have
delivered the rest.
