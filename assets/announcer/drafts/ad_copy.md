# Ad copy: the arena screens and the PA between matches (DRAFT: waiting on the lead)

> Round 5, audio X4. Text only: nothing here is recorded or rendered until the lead approves it (lead gate 1 for the
> recordings; render owns how screen text is drawn). The brands already exist in the PA's sponsor reads
> (`assets/announcer/lines.json`, `pa.sponsor.*`), so the screens and the booth advertise the same world.

## The rules this copy follows

From the lead's humor direction (game_design.md *The arena announcer*): *"the listener should just get the sense that
something's slightly off."* So every ad below is ordinary advertising (a real ad agency could have written it), and at
most **one** detail per ad is wrong, delivered flat. No jokes, no punchlines, no puns in brand names, no winking.
Brands are fictional and belong to this world only: no real companies, and nothing that imitates one.

**Screens** are read from across an arena at a 3 px/m overview, so a headline is at most four words and a line under
it at most eight. The wrongness goes in the small line, where it is noticed on the second look.

**PA reads** play between matches (pre-match and the results screen) and when the camera frames an ad screen. Each is
one whole sentence or two, recorded whole, so none carries a slot.

## The screens (headline / small line)

| Brand | Headline | Small line |
|---|---|---|
| AquaCorp | CLEAN WATER. EVERY WEEK. | For approved households. Schedules posted Mondays. |
| AquaCorp | HYDRATION IS HEALTH | Your allocation has been reviewed. |
| Syndicate Life | PROTECT WHAT MATTERS | Plans from one month of labor. |
| Syndicate Life | THEY'LL BE TAKEN CARE OF | Beneficiaries notified automatically. |
| Meridian Transport | GET THERE TOGETHER | District passes checked at every stop. |
| Harbor General | WE'RE HERE FOR YOU | Official hospital of the arena. Winners first. |
| Vireo | REAL FOOD. REAL ENERGY. | Now 92% food. |
| Northgrid Power | KEEPING THE LIGHTS ON | In selected residential areas. |
| Syndicate Vision | EVERY ANGLE. FOREVER. | All broadcasts archived permanently. |
| Syndicate Housing | A HOME IN THE EAST | Applications reviewed by lottery. |
| Syndicate Security | SEE SOMETHING. REPORT IT. | Reports during tonight's match earn double credit. |
| The Law | ORDER IS A PUBLIC GOOD | Tip lines open around the clock. |

## The PA between matches (Corporate Co-host)

- `pa.screen.01` Before tonight's match, please direct your attention to the screens above the north stand, where AquaCorp has posted tomorrow's water schedule.
- `pa.screen.02` Our thanks to Syndicate Life, whose representatives will be available on the lower concourse after the match to speak with crews' families.
- `pa.screen.03` Meridian Transport would like to remind everyone that the final train to the outer districts leaves forty minutes after the match, and will not wait.
- `pa.screen.04` Tonight's screens are powered by Northgrid, keeping the arena bright while the eastern districts observe their scheduled quiet hours.
- `pa.screen.05` The replays you see on tonight's screens are provided by Syndicate Vision. If you appear in a replay, no further action is required.
- `pa.screen.06` Vireo bars are available at every concession stand this evening. Fans in the upper bowl will receive theirs at the end of the match.
- `pa.screen.07` Harbor General thanks tonight's crews for their continued support of the arena's medical wing.
- `pa.screen.08` Syndicate Housing is now accepting applications in the eastern districts. Tonight's winning crew has been entered automatically.
- `pa.results.01` That concludes this evening's programme. Please take a moment to enjoy the screens while the floor is cleared.
- `pa.results.02` While the floor is prepared for the next match, a reminder that Syndicate Security reports made tonight will be credited by morning.
- `pa.results.03` The next match begins shortly. Fans who have been asked to remain in their seats should continue to do so.
- `pa.results.04` Thank you for joining us. Your attendance tonight has been recorded, and is appreciated.

## What the lead is asked

1. Do these read as believable ads with one thing slightly off, or do any read as a joke? (Cut or rewrite those.)
2. Screens: should they carry these brands at all, or live match content (the scoreboard, replays) most of the time
   with ads between? Roadmap mentions *"giant dystopian ad screens with live match content"*.
3. Recording the twelve PA lines costs about 1,500 credits (whole sentences, no slots).
