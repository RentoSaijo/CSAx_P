# Blinded Central Scouting external-validation codebook

## Purpose

This exercise asks whether CSAx agrees with hockey judgment recorded before the player entered the study window. One author rates official NHL Central Scouting prose while blinded to player identity, CSAx, and the public rankings. Each row represents one player.

Read only the supplied passage. Do not search distinctive phrases, consult the source catalog, infer the player from outside knowledge, or consult CSAx values or rankings until the completed file has been returned and locked.

## Coding order

Code the three content fields first, then finish with `overallPhysicality`. Use `notes` only when a brief explanation would document an ambiguity.

## Fields

`overallPhysicality`

- `+1`: The passage presents a player whose active engagement, interior work, strength, confrontation, or willingness is larger or heavier than the frame implied by the prose.
- `0`: The passage is balanced or gives no clear frame-relative direction.
- `-1`: The passage presents a comparatively softer, less confrontational, or easily displaced physical profile.

This is a frame-relative judgment. A large player described as merely using expected strength can receive 0, while a smaller player explicitly described as playing above his size can receive +1.
Merely absorbing contact or blocking shots does not establish a +1 rating.

`playsBiggerExplicit`

- `1`: The passage explicitly says that the player plays bigger, larger, stronger, heavier, or more physically than his size or frame suggests.
- `0`: No explicit frame-relative statement appears.

`activePhysicalEngagement`

- `1`: The passage describes initiating or delivering contact, checking, actively battling for contested pucks, confrontation, aggression, physical competitiveness, fighting, using strength to drive through opposition, or forceful interior work.
- `0`: The passage contains no such description. Merely absorbing contact or blocking a shot does not qualify by itself.

`interiorPlay`

- `1`: The passage describes work along the wall, in corners, through traffic, around the crease or net front, in tight space, or driving/protecting the puck toward the interior.
- `0`: The passage contains no such description.

`notes`

- Optional plain text for an ambiguity. Do not enter a guessed player name.

## Completion checks

Use only the permitted codes. Do not edit `studyId` or `reportText`, add or remove rows, sort by the wording of a passage, or expose a guessed identity. Save the completed file as CSV with the original filename. The file will be hashed and locked before the study key or CSAx values are joined. Every planned validation result will be reported regardless of its direction or statistical significance.
