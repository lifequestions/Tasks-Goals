# Brief: redraw 52 icons and rewrite 52 card texts

Paste everything below this line into the model. It is self-contained.

---

## What this is

cognitivebiases.co is a reference of 52 cognitive biases, presented as a deck of cards.
Each bias has a small icon that appears in two places: as a white glyph inside a coloured
circle on the home page dial (about 75px across), and as a white glyph on the card itself
(about 40px across). There are six categories, each with its own colour.

I need two things from you: **new icons** and **rewritten card text**.

## Part 1 — the icons

The current set is inconsistent and repetitive. Measured across the 52:

- **9 different stroke widths** are in use (1, 1.4, 1.5, 1.6, 1.8, 2, 2.2, 2.5 …), so
  nothing matches anything when the icons sit together on the dial.
- **Filled and outline styles are mixed arbitrarily**, often inside one icon, and
  `fill-opacity` is used at a dozen different values as a shading hack.
- **Whole families collapse into the same shape.** Six are built from two circles and a
  connecting path and read as near-identical at 32px; six more are three or more
  rectangles and all read as a bar chart (Scarcity Bias, Social Comparison,
  Survivorship Bias, Availability Cascade, Choice Overload, Zero-Risk Bias).
- Several are abstract to the point of carrying no meaning at all.

Draw 52 replacements. Hard constraints:

- **Inline SVG, no external references.** Format exactly: `<svg viewBox="0 0 32 32" fill="none">…</svg>`
- **Monochrome.** Use the literal string `white` for every stroke and fill. The site
  recolours them; do not use currentColor, hex values, gradients, filters or CSS.
- **One visual language across all 52.** Pick outline-first, `stroke-width="2"`,
  `stroke-linecap="round"`, `stroke-linejoin="round"`, and hold it. Use a filled shape
  only where it carries meaning (a weight, a chosen option), never for decoration.
- **Legible at 32px.** No detail finer than 1.5 units, nothing smaller than 3 units across,
  keep to a 2-unit margin inside the 32×32 box. No text, no numerals, no letters.
- **Every icon distinct.** If two biases would get the same shape, one of them is wrong.
  Check the whole set at the end for collisions.
- **Show the mechanism, not the topic.** The icon for Sunk Cost Fallacy should say
  "already spent, still going", not "money". A reader who knows the bias should recognise
  it; a reader who does not should at least see a difference in kind from its neighbours.

Output the icons as a JSON object: `{ "Loss Aversion": "<svg …>", … }` with all 52 keys,
spelled exactly as listed below.

## Part 2 — the card text

Each card carries two sentences:

- **description** — what the bias is. One sentence, plain spoken English.
- **example** — where you meet it. One concrete scene, not an abstraction.

Rules, because earlier drafts failed on exactly these:

- **Write how a person talks.** Contractions. "Your brain fills the gap", not
  "The mind is inclined to supply". No literary inversions, no "one tends to".
- **Second person where it fits.** The reader is the one with the bias, not a third party.
- **The description must not restate the name.** "Loss Aversion: you are averse to losses"
  is useless. Say what actually happens.
- **The example must be specific and ordinary** — a situation from work, money, family or
  a group chat. No "studies show", no "imagine that", no business-case hypotheticals.
- **Length:** description 12–22 words, example 12–22 words. Both single sentences.
- **No jargon** unless the bias is the jargon.

Output as JSON: `{ "Loss Aversion": { "description": "…", "example": "…" }, … }`,
all 52 keys, spelled exactly as listed.

## The categories

- **Money & Risk** (money) — Bad Bets & Irrational Risk. Is this a rational bet, or am I protecting my ego? Biases that distort how we handle money, investments, and risk.
- **Power & Leadership** (power) — Negotiation & Influence. Am I responding to status, framing, or actual leverage? Biases that distort power dynamics and negotiation.
- **Social & Relationships** (social) — Judgement & Tribal Thinking. Am I reacting to the person, or to my story about them? Biases that warp how we judge and relate to others.
- **Self-Deception** (ego) — Ego Protection. What belief am I emotionally protecting right now? Biases that defend identity instead of truth.
- **Narrative & Information** (narrative) — Media & Data Distortion. Am I seeing the full dataset or just the loudest example? Biases exploited by headlines, viral content, and selective data.
- **Decision Speed** (speed) — Action & Urgency Biases. Am I choosing what's optimal or what's easiest right now? Biases that make us rush into flawed decisions.

## The 52 biases

Current text is given so you can see the register to beat. Replace all of it.

### 1. Loss Aversion
- category: Money & Risk
- current description: Losses hurt about twice as much as equivalent gains feel good.
- current example: Holding a losing stock for months hoping it recovers rather than cutting losses.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><line x1="16" y1="4" x2="16" y2="10" stroke="white" stroke-width="2"/><line x1="6" y1="16" x2="26" y2="14" stroke="white" stroke-width="2"/><rect x="4" y="16" width="8" height="8" rx="2" fill="white" fill-opacity="0.9"/><rect x="20" y="14" width="8" height="5" rx="2" fill="white" fill-opacity="0.3"/></svg>`

### 2. Sunk Cost Fallacy
- category: Money & Risk
- current description: Continuing an endeavor because of past investment rather than evaluating its current or future value.
- current example: Watching a terrible movie to the end because you already paid for the ticket.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="11" cy="8" r="4" stroke="white" stroke-width="1.5" fill="none"/><circle cx="21" cy="8" r="4" stroke="white" stroke-width="1.5" fill="none"/><path d="M6 18 L16 27 L26 18" stroke="white" stroke-width="2" fill="none" stroke-linejoin="round"/><line x1="16" y1="27" x2="16" y2="31" stroke="white" stroke-width="2"/></svg>`

### 3. Anchoring Bias
- category: Money & Risk
- current description: The tendency to rely too heavily on the first piece of information encountered when making decisions.
- current example: A shirt marked down from $100 to $50 feels like a great deal, even if it's only worth $30.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="7" r="4" stroke="white" stroke-width="2" fill="none"/><line x1="16" y1="11" x2="16" y2="28" stroke="white" stroke-width="2"/><line x1="12" y1="17" x2="20" y2="17" stroke="white" stroke-width="2"/><path d="M10 24c0 3.3 2.7 6 6 6s6-2.7 6-6" stroke="white" stroke-width="1.5" fill="none"/></svg>`

### 4. Overconfidence Bias
- category: Money & Risk
- current description: Excessive confidence in your own answers, predictions, and abilities beyond what the evidence supports.
- current example: Day traders who believe they can consistently beat the market despite data showing most lose money.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="10" stroke="white" stroke-width="2" fill="none"/><path d="M16 6 L16 16 L23 16" stroke="white" stroke-width="2" stroke-linecap="round"/><circle cx="16" cy="16" r="2" fill="white"/></svg>`

### 5. Recency Bias
- category: Money & Risk
- current description: Overweighting recent events while discounting older information.
- current example: Investing heavily in a sector because it did well last quarter, ignoring long-term patterns.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="7" cy="16" r="2" fill="white" fill-opacity="0.15"/><circle cx="13" cy="16" r="3" fill="white" fill-opacity="0.3"/><circle cx="20" cy="16" r="4" fill="white" fill-opacity="0.5"/><circle cx="27" cy="15" r="5" fill="white"/></svg>`

### 6. Endowment Effect
- category: Money & Risk
- current description: Overvaluing what you already own simply because you own it.
- current example: Refusing to sell concert tickets for $200 even though you would never have paid that much.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="9" y="10" width="14" height="12" rx="3" stroke="white" stroke-width="2" fill="none"/><path d="M13 15 Q16 12 19 15 Q20 16 20 18 Q20 22 16 24 Q12 22 12 18 Q12 16 13 15Z" fill="white" fill-opacity="0.4"/></svg>`

### 7. Disposition Effect
- category: Money & Risk
- current description: Selling winners too early and holding losers too long to avoid realizing a loss.
- current example: Selling a stock that went up 10% immediately while bagholding one down 30% for months.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M6 24 L12 18 L18 14 L24 8" stroke="white" stroke-width="2" fill="none" stroke-linecap="round"/><circle cx="24" cy="8" r="2.5" fill="white"/><path d="M6 8 L12 14 L18 20 L24 26" stroke="white" stroke-width="1.5" stroke-dasharray="3 2" fill="none" opacity="0.4"/></svg>`

### 8. Optimism Bias
- category: Money & Risk
- current description: Overestimating positive outcomes for yourself while underestimating negative ones.
- current example: Most people believe they're less likely than average to go bankrupt or lose their job.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="14" r="8" stroke="white" stroke-width="2" fill="none"/><path d="M12 16 Q16 20 20 16" stroke="white" stroke-width="1.5" fill="none" stroke-linecap="round"/><line x1="16" y1="4" x2="16" y2="2" stroke="white" stroke-width="1.5"/><line x1="24" y1="8" x2="26" y2="6" stroke="white" stroke-width="1.5"/><line x1="8" y1="8" x2="6" y2="6" stroke="white" stroke-width="1.5"/></svg>`

### 9. Gambler's Fallacy
- category: Money & Risk
- current description: Past random results feel like they change the odds of the next one.
- current example: Betting bigger on red after five blacks in a row, as if the wheel owes you one.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="7" cy="16" r="2.6" fill="white" fill-opacity="0.85"/><circle cx="14" cy="16" r="2.6" fill="white" fill-opacity="0.85"/><circle cx="21" cy="16" r="2.6" fill="white" fill-opacity="0.85"/><circle cx="27" cy="16" r="3.4" stroke="white" stroke-width="1.6" stroke-dasharray="2 2" fill="none"/></svg>`

### 10. Authority Bias
- category: Power & Leadership
- current description: Giving extra weight to authority figures even when their expertise is irrelevant.
- current example: Following a celebrity's health advice over a doctor's recommendation.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="13" y="4" width="6" height="8" rx="1" fill="white"/><rect x="10" y="12" width="12" height="14" rx="2" stroke="white" stroke-width="2" fill="none"/><line x1="16" y1="26" x2="16" y2="30" stroke="white" stroke-width="2"/></svg>`

### 11. Status Quo Bias
- category: Power & Leadership
- current description: Preferring the current state of affairs. Changes from the baseline are perceived as a loss.
- current example: Sticking with your bank for decades despite far better options being available.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="10" stroke="white" stroke-width="2" fill="none"/><line x1="12" y1="16" x2="20" y2="16" stroke="white" stroke-width="2.5" stroke-linecap="round"/></svg>`

### 12. Framing Effect
- category: Power & Leadership
- current description: Reacting differently to the same information based on whether it's framed as a gain or loss.
- current example: "95% fat-free" sounds healthier than "contains 5% fat" — identical facts, different reactions.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="5" y="8" width="10" height="16" rx="2" stroke="white" stroke-width="2" fill="white" fill-opacity="0.2"/><rect x="17" y="8" width="10" height="16" rx="2" stroke="white" stroke-width="2" fill="white" fill-opacity="0.2"/><line x1="10" y1="14" x2="10" y2="20" stroke="white" stroke-width="2"/><circle cx="22" cy="16" r="3" fill="white" fill-opacity="0.5"/></svg>`

### 13. Reactance
- category: Power & Leadership
- current description: Doing the opposite of what's requested when you feel your freedom is threatened.
- current example: A teenager rebels against a rule specifically because they were told they must follow it.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="8" y="8" width="16" height="16" rx="3" stroke="white" stroke-width="2" fill="none"/><line x1="12" y1="12" x2="20" y2="20" stroke="white" stroke-width="2.5" stroke-linecap="round"/><line x1="20" y1="12" x2="12" y2="20" stroke="white" stroke-width="2.5" stroke-linecap="round"/></svg>`

### 14. False Consensus
- category: Power & Leadership
- current description: Overestimating how much others share your beliefs and behaviors.
- current example: Assuming most people share your political views because your friends do.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="10" cy="14" r="4" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.3"/><circle cx="22" cy="14" r="4" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.3"/><circle cx="16" cy="22" r="4" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.3"/><path d="M10 14 L22 14 M16 14 L16 22" stroke="white" stroke-width="1" opacity="0.4" stroke-dasharray="2 1.5"/></svg>`

### 15. Illusion of Control
- category: Power & Leadership
- current description: Overestimating your ability to influence events determined by chance.
- current example: Blowing on dice as if your breath could influence which numbers appear.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="8" y="6" width="16" height="20" rx="3" stroke="white" stroke-width="2" fill="none"/><circle cx="12" cy="14" r="2" fill="white"/><circle cx="20" cy="14" r="2" fill="white"/><line x1="12" y1="20" x2="20" y2="20" stroke="white" stroke-width="1.5"/></svg>`

### 16. Escalation of Commitment
- category: Power & Leadership
- current description: Increasing investment in a decision despite evidence it was wrong, to justify prior choices.
- current example: A leader doubling down on a failing strategy because reversing course would be an admission of error.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M8 26 L8 8 L14 8 L14 26" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.2"/><path d="M16 26 L16 14 L22 14 L22 26" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.4"/><path d="M24 26 L24 20 L28 20 L28 26" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.6"/><path d="M6 6 L28 18" stroke="white" stroke-width="1.5" stroke-dasharray="2 2" opacity="0.5"/></svg>`

### 17. Halo Effect
- category: Power & Leadership
- current description: A positive impression in one area spills over to influence opinions in unrelated areas.
- current example: Assuming an attractive person is also intelligent and kind with no supporting evidence.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="18" r="7" stroke="white" stroke-width="2" fill="none"/><ellipse cx="16" cy="9" rx="10" ry="3" stroke="white" stroke-width="1.5" fill="none"/></svg>`

### 18. Scarcity Bias
- category: Power & Leadership
- current description: Anything that looks like it's running out starts to look worth more.
- current example: Signing a contract the same day because the other side says the offer expires tonight.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="4" y="9" width="9" height="14" rx="2" stroke="white" stroke-width="1.6" fill="none" opacity="0.5"/><rect x="15" y="9" width="5" height="14" rx="2" fill="white" fill-opacity="0.55"/><rect x="22" y="9" width="2.5" height="14" rx="1.2" fill="white"/><path d="M27 12 L30 16 L27 20" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>`

### 19. Attribution Error
- category: Social & Relationships
- current description: Blaming others' behavior on their character but your own on the situation.
- current example: They cut you off: "What a jerk." You cut them off: "I'm running late."
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="10" r="5" stroke="white" stroke-width="2" fill="none"/><path d="M8 28 Q8 20 16 20 Q24 20 24 28" stroke="white" stroke-width="2" fill="none"/><line x1="26" y1="8" x2="22" y2="12" stroke="white" stroke-width="1.5" opacity="0.5"/></svg>`

### 20. In-Group Bias
- category: Social & Relationships
- current description: Favoring members of your own group with more trust, empathy, and positive attributions.
- current example: Rating a candidate higher because they went to the same university as you.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="12" cy="12" r="4" fill="white" fill-opacity="0.8"/><circle cx="20" cy="12" r="4" fill="white" fill-opacity="0.8"/><circle cx="16" cy="20" r="4" fill="white" fill-opacity="0.8"/><circle cx="16" cy="15" r="9" stroke="white" stroke-width="1.5" stroke-dasharray="3 2" fill="none"/></svg>`

### 21. Out-Group Homogeneity
- category: Social & Relationships
- current description: Seeing members of other groups as more alike than they really are, while seeing your own group as diverse.
- current example: "They're all the same" about a rival team's fans, while your own fans are each unique individuals.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="10" cy="16" r="3" fill="white"/><circle cx="16" cy="16" r="3" fill="white"/><circle cx="22" cy="16" r="3" fill="white"/><rect x="6" y="10" width="20" height="12" rx="6" stroke="white" stroke-width="1.5" stroke-dasharray="3 2" fill="none"/></svg>`

### 22. Projection Bias
- category: Social & Relationships
- current description: Assuming others think and feel the same way you do right now.
- current example: Shopping for groceries while hungry and buying far too much food.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="10" cy="14" r="5" stroke="white" stroke-width="2" fill="none"/><circle cx="22" cy="14" r="5" stroke="white" stroke-width="2" fill="none"/><path d="M15 14 L17 14" stroke="white" stroke-width="2" stroke-dasharray="1.5 1.5"/></svg>`

### 23. Stereotyping
- category: Social & Relationships
- current description: Applying generalized beliefs about a group to an individual without evidence.
- current example: Assuming an older colleague can't learn new software without ever asking them.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="8" y="8" width="16" height="16" rx="2" stroke="white" stroke-width="2" fill="none"/><circle cx="13" cy="14" r="2" fill="white"/><circle cx="19" cy="14" r="2" fill="white"/><line x1="12" y1="20" x2="20" y2="20" stroke="white" stroke-width="1.5" stroke-linecap="round"/></svg>`

### 24. Social Comparison
- category: Social & Relationships
- current description: Evaluating yourself by comparing to others, leading to envy or false superiority.
- current example: Feeling successful until you see a friend's promotion on social media, then suddenly feeling behind.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="6" y="18" width="6" height="10" rx="1" fill="white" fill-opacity="0.3"/><rect x="13" y="12" width="6" height="16" rx="1" fill="white" fill-opacity="0.5"/><rect x="20" y="6" width="6" height="22" rx="1" fill="white" fill-opacity="0.8"/><path d="M9 16 L16 10 L23 4" stroke="white" stroke-width="1.5" stroke-dasharray="2 2" opacity="0.5" fill="none"/></svg>`

### 25. Just-World Hypothesis
- category: Social & Relationships
- current description: Believing people get what they deserve, leading to victim-blaming.
- current example: Assuming someone who lost their job must have done something wrong rather than being unlucky.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><line x1="16" y1="6" x2="16" y2="10" stroke="white" stroke-width="2"/><line x1="8" y1="16" x2="24" y2="16" stroke="white" stroke-width="2"/><rect x="6" y="16" width="8" height="6" rx="1" fill="white" fill-opacity="0.4"/><rect x="18" y="16" width="8" height="6" rx="1" fill="white" fill-opacity="0.4"/><line x1="12" y1="26" x2="20" y2="26" stroke="white" stroke-width="2"/></svg>`

### 26. Bystander Effect
- category: Social & Relationships
- current description: The more people who could step in, the less likely any one of them does.
- current example: Nobody picking up a thread addressed to the whole team, because it wasn't addressed to anyone.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="4.5" stroke="white" stroke-width="2" fill="none"/><circle cx="16" cy="5" r="2.2" fill="white" fill-opacity="0.3"/><circle cx="16" cy="27" r="2.2" fill="white" fill-opacity="0.3"/><circle cx="5" cy="16" r="2.2" fill="white" fill-opacity="0.3"/><circle cx="27" cy="16" r="2.2" fill="white" fill-opacity="0.3"/><circle cx="8" cy="8" r="2.2" fill="white" fill-opacity="0.3"/><circle cx="24" cy="24" r="2.2" fill="white" fill-opacity="0.3"/></svg>`

### 27. Bandwagon Effect
- category: Social & Relationships
- current description: Something feels more true the more people you can see believing it.
- current example: Backing the option the room has already nodded at, before you've read the detail.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="6" cy="23" r="2" fill="white" fill-opacity="0.3"/><circle cx="12" cy="20" r="2.6" fill="white" fill-opacity="0.5"/><circle cx="19" cy="16" r="3.2" fill="white" fill-opacity="0.75"/><circle cx="26" cy="11" r="3.8" fill="white"/><path d="M4 28 L28 28" stroke="white" stroke-width="1.5" opacity="0.4" stroke-linecap="round"/></svg>`

### 28. Confirmation Bias
- category: Self-Deception
- current description: Searching for and favoring information that confirms preexisting beliefs while ignoring contradictory evidence.
- current example: After choosing a car, you only notice articles praising it and skip critical reviews.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="14" cy="14" r="8" stroke="white" stroke-width="2" fill="none"/><line x1="20" y1="20" x2="28" y2="28" stroke="white" stroke-width="2.5" stroke-linecap="round"/><path d="M11 14 L13 16 L18 11" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`

### 29. Self-Serving Bias
- category: Self-Deception
- current description: Attributing success to skill and failure to bad luck, protecting self-esteem.
- current example: Aced the exam? "I studied hard." Failed? "The questions were unfair."
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="12" r="6" stroke="white" stroke-width="2" fill="none"/><path d="M16 6 L17 3 L18 6" stroke="white" stroke-width="1.5" fill="white"/><path d="M10 26 Q10 20 16 20 Q22 20 22 26" stroke="white" stroke-width="2" fill="none"/></svg>`

### 30. Dunning-Kruger Effect
- category: Self-Deception
- current description: Low expertise leads to overconfidence, while high expertise leads to self-doubt.
- current example: A beginner thinks three chords make them stage-ready. A pro worries they're not good enough.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M4 26 Q10 6 16 18 Q22 26 28 10" stroke="white" stroke-width="2" fill="none" stroke-linecap="round"/><circle cx="10" cy="10" r="2" fill="white"/></svg>`

### 31. Bias Blind Spot
- category: Self-Deception
- current description: Recognizing cognitive biases in others but failing to see them in yourself.
- current example: Pointing out a friend's confirmation bias while being completely unaware of your own.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="10" stroke="white" stroke-width="2" fill="none"/><circle cx="16" cy="16" r="4" fill="white"/><line x1="6" y1="6" x2="26" y2="26" stroke="white" stroke-width="2" opacity="0.4"/></svg>`

### 32. Consistency Bias
- category: Self-Deception
- current description: Misremembering your past beliefs as being more similar to your current ones than they actually were.
- current example: Claiming you "always knew" a startup would succeed after it becomes a unicorn.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><line x1="6" y1="16" x2="26" y2="16" stroke="white" stroke-width="2" stroke-linecap="round"/><circle cx="10" cy="10" r="3" stroke="white" stroke-width="1.5" fill="none" opacity="0.3"/><circle cx="22" cy="10" r="3" fill="white" fill-opacity="0.8"/><path d="M10 10 L22 10" stroke="white" stroke-width="1" stroke-dasharray="2 2" opacity="0.4"/></svg>`

### 33. Hindsight Bias
- category: Self-Deception
- current description: Seeing past events as predictable after the fact. The "I knew it all along" effect.
- current example: After a crash, insisting you "knew" the market would fall when you had no such conviction.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="10" stroke="white" stroke-width="2" fill="none"/><path d="M12 14 L16 10 L20 14" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/><line x1="16" y1="10" x2="16" y2="22" stroke="white" stroke-width="2" stroke-linecap="round"/></svg>`

### 34. Illusion of Explanatory Depth
- category: Self-Deception
- current description: Believing you understand complex systems far better than you actually do.
- current example: Confidently explaining how a toilet works, then stumbling when asked for actual mechanical details.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="8" y="6" width="16" height="20" rx="2" stroke="white" stroke-width="2" fill="none"/><line x1="12" y1="12" x2="20" y2="12" stroke="white" stroke-width="1.5" opacity="0.7"/><line x1="12" y1="16" x2="18" y2="16" stroke="white" stroke-width="1.5" opacity="0.4"/><line x1="12" y1="20" x2="15" y2="20" stroke="white" stroke-width="1.5" opacity="0.2"/></svg>`

### 35. Moral Licensing
- category: Self-Deception
- current description: Doing one good thing quietly buys you permission to do a worse one next.
- current example: Treating a healthy lunch as credit towards skipping the gym all week.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><line x1="16" y1="6" x2="16" y2="26" stroke="white" stroke-width="1.8" stroke-linecap="round"/><line x1="7" y1="12" x2="25" y2="9" stroke="white" stroke-width="1.8" stroke-linecap="round"/><rect x="4" y="13" width="7" height="6" rx="1.6" fill="white" fill-opacity="0.9"/><rect x="21" y="10" width="7" height="6" rx="1.6" stroke="white" stroke-width="1.4" fill="none" opacity="0.6"/></svg>`

### 36. Ostrich Effect
- category: Self-Deception
- current description: When the news is likely to be bad, you just don't look.
- current example: Not opening the portfolio for months after the market drops.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M5 20 Q16 10 27 20" stroke="white" stroke-width="1.8" fill="none" stroke-linecap="round"/><circle cx="16" cy="17" r="2.8" fill="white" fill-opacity="0.9"/><path d="M7 8 L25 26" stroke="white" stroke-width="2.2" stroke-linecap="round"/></svg>`

### 37. Availability Heuristic
- category: Narrative & Information
- current description: Overestimating the likelihood of vivid, recent, or emotionally charged events.
- current example: Fearing flights after crash coverage despite flying being statistically one of the safest ways to travel.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="16" cy="16" r="10" stroke="white" stroke-width="2" fill="none"/><path d="M16 10 L16 16 L21 19" stroke="white" stroke-width="2" stroke-linecap="round"/><path d="M22 6 L26 4" stroke="white" stroke-width="1.5" opacity="0.5"/></svg>`

### 38. Survivorship Bias
- category: Narrative & Information
- current description: Focusing only on successes while ignoring the far more numerous failures.
- current example: Studying successful dropouts and concluding college is unnecessary.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="6" y="20" width="4" height="8" rx="1" fill="white" fill-opacity="0.2"/><rect x="12" y="16" width="4" height="12" rx="1" fill="white" fill-opacity="0.2"/><rect x="18" y="12" width="4" height="16" rx="1" fill="white" fill-opacity="0.3"/><rect x="24" y="6" width="4" height="22" rx="1" fill="white"/><circle cx="26" cy="6" r="2" fill="white"/></svg>`

### 39. Narrative Fallacy
- category: Narrative & Information
- current description: Constructing simple stories to explain complex events, creating false cause-and-effect.
- current example: Attributing a company's success to one brilliant decision when countless factors were at play.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M6 20 Q10 10 16 16 Q22 22 26 12" stroke="white" stroke-width="2" fill="none" stroke-linecap="round"/><circle cx="6" cy="20" r="2" fill="white"/><circle cx="26" cy="12" r="2" fill="white"/></svg>`

### 40. Clustering Illusion
- category: Narrative & Information
- current description: Seeing meaningful patterns in random data where none actually exist.
- current example: Believing a basketball player has a "hot hand" when it's within normal random variation.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="8" cy="10" r="2" fill="white" fill-opacity="0.5"/><circle cx="14" cy="8" r="2" fill="white" fill-opacity="0.5"/><circle cx="11" cy="14" r="2" fill="white" fill-opacity="0.5"/><circle cx="22" cy="20" r="2" fill="white" fill-opacity="0.3"/><circle cx="26" cy="14" r="2" fill="white" fill-opacity="0.3"/><circle cx="18" cy="24" r="2" fill="white" fill-opacity="0.3"/><ellipse cx="11" cy="11" rx="7" ry="6" stroke="white" stroke-width="1.5" stroke-dasharray="2 2" fill="none"/></svg>`

### 41. Illusory Correlation
- category: Narrative & Information
- current description: Perceiving a relationship between two unrelated things because they co-occurred.
- current example: Believing you always hit red lights when running late, though the rate is the same as usual.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="10" cy="16" r="6" stroke="white" stroke-width="1.5" fill="none"/><circle cx="22" cy="16" r="6" stroke="white" stroke-width="1.5" fill="none"/><path d="M14 12 L18 20 M14 20 L18 12" stroke="white" stroke-width="1" opacity="0.5"/></svg>`

### 42. Base Rate Neglect
- category: Narrative & Information
- current description: Ignoring statistical base rates in favor of specific, individual information.
- current example: Assuming a "quiet bookworm" is a librarian when salespeople vastly outnumber them.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="4" y="20" width="24" height="6" rx="2" fill="white" fill-opacity="0.2"/><rect x="4" y="20" width="6" height="6" rx="2" fill="white" fill-opacity="0.8"/><circle cx="16" cy="11" r="6" stroke="white" stroke-width="2" fill="none"/><line x1="16" y1="8" x2="16" y2="14" stroke="white" stroke-width="1.5"/><line x1="13" y1="11" x2="19" y2="11" stroke="white" stroke-width="1.5"/></svg>`

### 43. Peak-End Rule
- category: Narrative & Information
- current description: Judging an experience by its most intense moment and its ending, not the average.
- current example: Rating a vacation as great because of one amazing dinner and a smooth flight home.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M4 24 L10 18 L16 8 L22 16 L28 20" stroke="white" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle cx="16" cy="8" r="2.5" fill="white"/><circle cx="28" cy="20" r="2.5" fill="white"/></svg>`

### 44. Curse of Knowledge
- category: Narrative & Information
- current description: Once you know something, you can't picture what it's like not to.
- current example: Writing a handover doc that only makes sense to the person who wrote it.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="9" cy="16" r="5.5" stroke="white" stroke-width="1.8" fill="none"/><circle cx="9" cy="16" r="2" fill="white"/><circle cx="24" cy="16" r="5.5" stroke="white" stroke-width="1.6" stroke-dasharray="2 2" fill="none" opacity="0.6"/><path d="M16 14 L19 14" stroke="white" stroke-width="1.6" stroke-linecap="round" opacity="0.5"/></svg>`

### 45. Availability Cascade
- category: Narrative & Information
- current description: A claim repeated often enough starts to feel like settled fact.
- current example: A statistic quoted everywhere because everyone's quoting it, not because anyone checked it.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="3" y="17" width="5" height="5" rx="1.4" fill="white" fill-opacity="0.35"/><rect x="10" y="15" width="6.5" height="6.5" rx="1.6" fill="white" fill-opacity="0.6"/><rect x="18.5" y="12" width="9" height="9" rx="2" fill="white"/><path d="M4 27 Q16 30 28 27" stroke="white" stroke-width="1.4" opacity="0.4" fill="none" stroke-linecap="round"/></svg>`

### 46. Planning Fallacy
- category: Decision Speed
- current description: Underestimating time and cost while overestimating benefits, even with past experience.
- current example: Estimating a 3-week, $10k renovation that takes 3 months and costs $30k.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="7" y="7" width="18" height="18" rx="3" stroke="white" stroke-width="2" fill="none"/><line x1="7" y1="13" x2="25" y2="13" stroke="white" stroke-width="1.5"/><line x1="12" y1="7" x2="12" y2="13" stroke="white" stroke-width="1.5"/><line x1="20" y1="7" x2="20" y2="13" stroke="white" stroke-width="1.5"/><path d="M12 18 L15 21 L20 16" stroke="white" stroke-width="1.5" fill="none" stroke-linecap="round"/></svg>`

### 47. Action Bias
- category: Decision Speed
- current description: Preferring to do something rather than nothing, even when inaction would be more effective.
- current example: A goalkeeper always dives left or right, but staying center would save more penalties.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M8 16 L24 16" stroke="white" stroke-width="2.5" stroke-linecap="round"/><path d="M20 11 L26 16 L20 21" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>`

### 48. Default Effect
- category: Decision Speed
- current description: Sticking with the pre-selected option because changing requires effort.
- current example: Organ donation rates are drastically higher in countries where it's the default option.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="6" y="10" width="20" height="12" rx="3" stroke="white" stroke-width="2" fill="none"/><rect x="8" y="12" width="8" height="8" rx="2" fill="white" fill-opacity="0.5"/></svg>`

### 49. Decoy Effect
- category: Decision Speed
- current description: A third "decoy" option shifts preference toward one of the original two by making it look better.
- current example: Small $4, medium $6.50, large $7 popcorn makes the large seem like the obvious best deal.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><circle cx="10" cy="20" r="4" stroke="white" stroke-width="1.5" fill="white" fill-opacity="0.2"/><circle cx="22" cy="12" r="6" fill="white" fill-opacity="0.7"/><circle cx="18" cy="22" r="3" stroke="white" stroke-width="1" fill="none" opacity="0.3" stroke-dasharray="2 1"/></svg>`

### 50. Hyperbolic Discounting
- category: Decision Speed
- current description: Preferring smaller immediate rewards over larger future ones, disproportionately.
- current example: Choosing $50 today over $100 in a month, but not choosing $50 in 12 months over $100 in 13.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><path d="M4 8 Q12 8 16 16 Q20 24 28 24" stroke="white" stroke-width="2" fill="none" stroke-linecap="round"/><circle cx="8" cy="8" r="3" fill="white"/><circle cx="24" cy="24" r="2" fill="white" fill-opacity="0.3"/></svg>`

### 51. Choice Overload
- category: Decision Speed
- current description: Past a certain point, more options make it harder to pick any of them.
- current example: Closing the streaming app after twenty minutes of scrolling without watching anything.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="4" y="5" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.6"/><rect x="13" y="5" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.6"/><rect x="4" y="13" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.4"/><rect x="13" y="13" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.4"/><rect x="4" y="21" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.25"/><rect x="13" y="21" width="7" height="6" rx="1.4" stroke="white" stroke-width="1.4" fill="none" opacity="0.25"/><circle cx="26" cy="16" r="4" stroke="white" stroke-width="1.8" fill="none"/></svg>`

### 52. Zero-Risk Bias
- category: Decision Speed
- current description: Wiping out one small risk entirely beats halving a much bigger one.
- current example: Spending the security budget closing a minor hole while the main one stays open.
- current icon: `<svg viewBox="0 0 32 32" fill="none"><rect x="3" y="11" width="11" height="10" rx="2" stroke="white" stroke-width="1.7" fill="none"/><path d="M6 16 L8.5 18.5 L11.5 13.5" stroke="white" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" fill="none"/><rect x="18" y="6" width="12" height="20" rx="2" stroke="white" stroke-width="1.7" stroke-dasharray="3 2" fill="none"/><rect x="18" y="16" width="12" height="10" rx="0" fill="white" fill-opacity="0.35"/></svg>`

---

## How to hand the result back

Two JSON blocks, nothing else:

1. `icons.json` — `{ "<bias name>": "<svg …>" }`, 52 keys.
2. `copy.json` — `{ "<bias name>": { "description": "…", "example": "…" } }`, 52 keys.

Names must match the spelling above exactly, including `Gambler's Fallacy` (straight
apostrophe) and `Dunning-Kruger Effect` (hyphen, not en dash). Any key that does not match
will be dropped on import.

## Before you answer

Check your own set against these, and fix anything that fails:

- Count the keys. 52 in each file.
- Every `stroke-width` in the icon set is the same number.
- No icon contains `currentColor`, a `#` colour, `<text>`, or a `style=` attribute.
- Read the 52 icons as a list of one-line shape descriptions. Any two that would read the
  same sentence are a collision — redraw one.
- Read the 52 descriptions aloud. Any that restates its own title, or that you would never
  say to a person, gets rewritten.
