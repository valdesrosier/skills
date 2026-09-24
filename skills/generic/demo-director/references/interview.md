# Focused discovery

Ask one question at a time. Carry answers forward; use a short decision ledger in
the demo job, not a permanent profile of the person. Do not interrogate the user
about facts that authorized inspection can determine.

## Mandatory host choice

Before hardware, OS, display, process, or window probes:

> Would you like to provide the recording computer's hardware and OS, or may I
> identify the basic environment with a limited read-only check?

Choices:
- I'll provide the hardware and OS.
- Identify the basic environment with my approval.

If provided: ask for OS/version, laptop/desktop, relevant display(s)/scaling, and
whether the recording is local, remote, virtual, or headless as needed. Do not run
inventory anyway. If discovery is approved: collect only OS/version, CPU
architecture, whether this is the actual capture host, and necessary capture/display
capabilities. Ask for additional scoped discovery before enumerating target windows.
Do not collect serial numbers, usernames, hostnames, IPs, device IDs, full
environment variables, installed-app inventories, or unrelated window titles.

An inventory result cannot reliably tell whether a lid is closed, a docking
configuration is safe, a remote display persists, or a projector is the intended
monitor. Ask. A remote shell's OS is not proof of the user's visible desktop.

## Core interview

Use adaptive order. Product decisions precede detailed production questions.

| Decision | Example question / choices |
|---|---|
| Audience and placement | Who is watching, and what will they already have seen? |
| One takeaway | What should they believe or be able to do after the demo? |
| Runtime | What is the target length, and is it a hard limit? |
| Product/scenario | Which app and one end-to-end task should carry the story? |
| Payoff | Which real outcome should be the memorable reveal? |
| Required/forbidden | What must appear, and what names, data, claims, or screens must not? |
| Evidence | Live execution, prepared real run, or replay of verified responses? |
| Audio (always ask) | Silent for live narration; recorded voiceover; system audio; specified combination |
| Style | Restrained product demo; energetic conference closer; instructional walkthrough |
| Variants | One theme; matched light/dark; other approved versions |
| Access | Browser URL or native app; backend readiness; permitted accounts/data |
| Delivery | Resolution/aspect ratio, final files, location, script/captions/Word, deadline |

Do not ask all rows if the opening brief answers them. Avoid bundled questions with
several unrelated decisions. A freeform answer may resolve several rows naturally.

## Confirmation before scripting

Summarize: audience, promise, task, runtime, payoff, sources/limits, audio, surfaces,
variants, host route, and deliverables. Mark unknowns explicitly. Offer proposed
defaults for final hold and restrained visual treatment rather than requiring
micro-approval of every cut.

## Approval and revision

Script approval must be affirmative and tied to a version. Silence, "looks
interesting," a prior demo's approval, or granting screen permissions is not enough.
Ask if ambiguous. Approval can cover rehearsal and production together; hardware
permissions, temporary sleep inhibition, product changes, and external publication
remain separate authorities.

During revisions, ask only what changed. Preserve approvals for unchanged production
constraints; reapprove changed story, narration, claims, runtime, or surfaces.
